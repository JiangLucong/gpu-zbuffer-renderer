// =============================================================================
//  CUDA Z-buffer rasterizer
//
//  A lightweight GPU rasterizing renderer. Each CUDA thread owns one output
//  pixel and independently performs triangle coverage + Z-buffer depth testing
//  over the whole mesh, demonstrating the parallelism of the Z-buffer algorithm.
//
//  Pipeline:
//    host : load OBJ -> rotate -> orthographic screen mapping -> per-face
//           flat Lambert shading -> upload triangles to the device
//    GPU  : clear kernel (framebuffer + Z-buffer) -> raster kernel
//           (one thread per pixel, barycentric coverage + depth test)
//    host : copy framebuffer back, write a 24-bit BMP
//
//  Build:   nvcc -O2 src/renderer.cu -o renderer
//           (or use the provided CMakeLists.txt)
//  Run:     ./renderer [model.obj] [width] [height] [out.bmp]
//           defaults: assets/monkey.obj 1024 1024 render.bmp
// =============================================================================

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <limits>

// ---- tiny CUDA error check ---------------------------------------------------
#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t _e = (call);                                               \
        if (_e != cudaSuccess) {                                               \
            std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__, \
                         cudaGetErrorString(_e));                              \
            std::exit(EXIT_FAILURE);                                           \
        }                                                                      \
    } while (0)

// ---- small vector helpers ----------------------------------------------------
struct Vec3 { float x, y, z; };

__host__ __device__ inline Vec3 operator-(Vec3 a, Vec3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
__host__ __device__ inline Vec3 cross(Vec3 a, Vec3 b) {
    return {a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x};
}
__host__ __device__ inline float dot(Vec3 a, Vec3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
__host__ __device__ inline Vec3 normalize(Vec3 v) {
    float n = sqrtf(v.x*v.x + v.y*v.y + v.z*v.z);
    if (n < 1e-12f) return {0.f, 0.f, 0.f};
    return {v.x/n, v.y/n, v.z/n};
}

// A triangle ready for rasterization: screen-space xy, depth per vertex, color.
struct Tri {
    float x0, y0, z0;
    float x1, y1, z1;
    float x2, y2, z2;
    unsigned char r, g, b;
};

// =============================================================================
//  Device kernels
// =============================================================================

// Background color + far depth. zbuffer convention: larger z == nearer viewer.
__global__ void clearKernel(unsigned char* fb, float* zb, int w, int h,
                            unsigned char bgR, unsigned char bgG, unsigned char bgB) {
    int px = blockIdx.x * blockDim.x + threadIdx.x;
    int py = blockIdx.y * blockDim.y + threadIdx.y;
    if (px >= w || py >= h) return;
    int idx = py * w + px;
    fb[idx*3+0] = bgR; fb[idx*3+1] = bgG; fb[idx*3+2] = bgB;
    zb[idx] = -1e30f;
}

__device__ inline float edge(float ax, float ay, float bx, float by, float cx, float cy) {
    return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
}

// One thread = one pixel. Loop every triangle, do half-space coverage test,
// interpolate depth via barycentric weights, keep the nearest fragment.
__global__ void rasterKernel(const Tri* tris, int numTris,
                             unsigned char* fb, float* zb, int w, int h) {
    int px = blockIdx.x * blockDim.x + threadIdx.x;
    int py = blockIdx.y * blockDim.y + threadIdx.y;
    if (px >= w || py >= h) return;

    int idx = py * w + px;
    float fx = px + 0.5f;          // sample at pixel center
    float fy = py + 0.5f;

    float bestZ = zb[idx];
    unsigned char cr = fb[idx*3+0], cg = fb[idx*3+1], cb = fb[idx*3+2];

    for (int t = 0; t < numTris; ++t) {
        Tri tr = tris[t];
        float area = edge(tr.x0, tr.y0, tr.x1, tr.y1, tr.x2, tr.y2);
        if (fabsf(area) < 1e-7f) continue;           // degenerate

        float w0 = edge(tr.x1, tr.y1, tr.x2, tr.y2, fx, fy);
        float w1 = edge(tr.x2, tr.y2, tr.x0, tr.y0, fx, fy);
        float w2 = edge(tr.x0, tr.y0, tr.x1, tr.y1, fx, fy);

        // inside if all weights share the sign of the triangle area
        bool inside = (w0 >= 0 && w1 >= 0 && w2 >= 0) ||
                      (w0 <= 0 && w1 <= 0 && w2 <= 0);
        if (!inside) continue;

        float l0 = w0 / area, l1 = w1 / area, l2 = w2 / area;
        float z = l0 * tr.z0 + l1 * tr.z1 + l2 * tr.z2;

        if (z > bestZ) {           // nearer than what we have -> Z-buffer update
            bestZ = z;
            cr = tr.r; cg = tr.g; cb = tr.b;
        }
    }

    zb[idx] = bestZ;
    fb[idx*3+0] = cr; fb[idx*3+1] = cg; fb[idx*3+2] = cb;
}

// =============================================================================
//  Host helpers
// =============================================================================

// Minimal OBJ loader: reads "v x y z" and triangulated "f a/b/c ..." faces
// (fan-triangulates polygons; uses only the vertex index before the first '/').
static bool loadObj(const std::string& path, std::vector<Vec3>& verts,
                    std::vector<int>& faces /* flat, 3 indices per tri */) {
    std::ifstream in(path);
    if (!in) return false;
    std::string line;
    while (std::getline(in, line)) {
        if (line.size() < 2) continue;
        std::istringstream ss(line);
        std::string tag; ss >> tag;
        if (tag == "v") {
            Vec3 v; ss >> v.x >> v.y >> v.z; verts.push_back(v);
        } else if (tag == "f") {
            std::vector<int> idx;
            std::string tok;
            while (ss >> tok) {
                int vi = std::atoi(tok.c_str());      // stops at '/'
                if (vi < 0) vi = (int)verts.size() + vi + 1;  // negative ref
                idx.push_back(vi - 1);                 // OBJ is 1-based
            }
            for (size_t k = 1; k + 1 < idx.size(); ++k) { // fan triangulation
                faces.push_back(idx[0]);
                faces.push_back(idx[k]);
                faces.push_back(idx[k + 1]);
            }
        }
    }
    return !verts.empty() && !faces.empty();
}

// Write a 24-bit (BGR, bottom-up) BMP — natively viewable on Windows.
static void writeBMP(const std::string& path, int w, int h, const unsigned char* rgb) {
    int rowSize = (w * 3 + 3) & ~3;          // pad each row to 4 bytes
    int dataSize = rowSize * h;
    int fileSize = 54 + dataSize;
    std::ofstream out(path, std::ios::binary);
    unsigned char hdr[54] = {0};
    hdr[0]='B'; hdr[1]='M';
    hdr[2]=fileSize; hdr[3]=fileSize>>8; hdr[4]=fileSize>>16; hdr[5]=fileSize>>24;
    hdr[10]=54;                               // pixel data offset
    hdr[14]=40;                               // DIB header size
    hdr[18]=w; hdr[19]=w>>8; hdr[20]=w>>16; hdr[21]=w>>24;
    hdr[22]=h; hdr[23]=h>>8; hdr[24]=h>>16; hdr[25]=h>>24;
    hdr[26]=1;                                // planes
    hdr[28]=24;                               // bits per pixel
    hdr[34]=dataSize; hdr[35]=dataSize>>8; hdr[36]=dataSize>>16; hdr[37]=dataSize>>24;
    out.write((char*)hdr, 54);
    std::vector<unsigned char> row(rowSize, 0);
    for (int y = h - 1; y >= 0; --y) {        // BMP rows are bottom-up
        for (int x = 0; x < w; ++x) {
            int i = (y * w + x) * 3;
            row[x*3+0] = rgb[i+2];            // B
            row[x*3+1] = rgb[i+1];            // G
            row[x*3+2] = rgb[i+0];            // R
        }
        out.write((char*)row.data(), rowSize);
    }
}

int main(int argc, char** argv) {
    std::string objPath = (argc > 1) ? argv[1] : "assets/monkey.obj";
    int W = (argc > 2) ? std::atoi(argv[2]) : 1024;
    int H = (argc > 3) ? std::atoi(argv[3]) : 1024;
    std::string outPath = (argc > 4) ? argv[4] : "render.bmp";

    // ---- load model ----------------------------------------------------------
    std::vector<Vec3> verts;
    std::vector<int>  faces;
    if (!loadObj(objPath, verts, faces)) {
        std::fprintf(stderr, "Failed to load OBJ: %s\n", objPath.c_str());
        return EXIT_FAILURE;
    }
    int numTris = (int)faces.size() / 3;
    std::printf("Loaded %s : %zu vertices, %d triangles\n",
                objPath.c_str(), verts.size(), numTris);

    // ---- rotate the model for a pleasant 3/4 view ----------------------------
    const float ay = 0.6f, ax = 0.35f;       // yaw, pitch (radians)
    float cy = cosf(ay), sy = sinf(ay), cx = cosf(ax), sx = sinf(ax);
    std::vector<Vec3> rot(verts.size());
    for (size_t i = 0; i < verts.size(); ++i) {
        Vec3 v = verts[i];
        Vec3 a = { cy*v.x + sy*v.z, v.y, -sy*v.x + cy*v.z };   // rotate about Y
        rot[i]  = { a.x, cx*a.y - sx*a.z, sx*a.y + cx*a.z };   // rotate about X
    }

    // ---- orthographic screen mapping (auto-fit with margin) ------------------
    Vec3 lo = { 1e30f, 1e30f, 1e30f}, hi = {-1e30f,-1e30f,-1e30f};
    for (auto& v : rot) {
        lo.x = fminf(lo.x, v.x); lo.y = fminf(lo.y, v.y); lo.z = fminf(lo.z, v.z);
        hi.x = fmaxf(hi.x, v.x); hi.y = fmaxf(hi.y, v.y); hi.z = fmaxf(hi.z, v.z);
    }
    float spanX = hi.x - lo.x, spanY = hi.y - lo.y;
    float span  = fmaxf(spanX, spanY);
    float scale = 0.9f * fminf(W, H) / (span > 1e-6f ? span : 1.f);
    float midX = 0.5f * (lo.x + hi.x), midY = 0.5f * (lo.y + hi.y);

    auto toScreenX = [&](float x){ return W * 0.5f + (x - midX) * scale; };
    auto toScreenY = [&](float y){ return H * 0.5f - (y - midY) * scale; }; // flip Y

    // ---- per-face flat Lambert shading -> triangle list ----------------------
    const Vec3 lightDir = normalize({0.4f, 0.6f, 0.8f});  // toward viewer-ish
    const float ambient = 0.2f;
    const Vec3 baseColor = {210.f, 210.f, 215.f};
    std::vector<Tri> tris(numTris);
    for (int t = 0; t < numTris; ++t) {
        Vec3 a = rot[faces[t*3+0]];
        Vec3 b = rot[faces[t*3+1]];
        Vec3 c = rot[faces[t*3+2]];
        Vec3 n = normalize(cross(b - a, c - a));
        if (n.z < 0.f) { n.x=-n.x; n.y=-n.y; n.z=-n.z; }   // face the viewer (+Z)
        float diff = fmaxf(0.f, dot(n, lightDir));
        float inten = fminf(1.f, ambient + (1.f - ambient) * diff);
        Tri tr;
        tr.x0 = toScreenX(a.x); tr.y0 = toScreenY(a.y); tr.z0 = a.z;
        tr.x1 = toScreenX(b.x); tr.y1 = toScreenY(b.y); tr.z1 = b.z;
        tr.x2 = toScreenX(c.x); tr.y2 = toScreenY(c.y); tr.z2 = c.z;
        tr.r = (unsigned char)(baseColor.x * inten);
        tr.g = (unsigned char)(baseColor.y * inten);
        tr.b = (unsigned char)(baseColor.z * inten);
        tris[t] = tr;
    }

    // ---- device buffers ------------------------------------------------------
    Tri* d_tris = nullptr;
    unsigned char* d_fb = nullptr;
    float* d_zb = nullptr;
    size_t fbBytes = (size_t)W * H * 3;
    CUDA_CHECK(cudaMalloc(&d_tris, tris.size() * sizeof(Tri)));
    CUDA_CHECK(cudaMalloc(&d_fb, fbBytes));
    CUDA_CHECK(cudaMalloc(&d_zb, (size_t)W * H * sizeof(float)));
    CUDA_CHECK(cudaMemcpy(d_tris, tris.data(), tris.size() * sizeof(Tri),
                          cudaMemcpyHostToDevice));

    dim3 block(16, 16);
    dim3 grid((W + block.x - 1) / block.x, (H + block.y - 1) / block.y);

    std::vector<unsigned char> framebuffer(fbBytes);

    auto renderOnce = [&]() {
        clearKernel<<<grid, block>>>(d_fb, d_zb, W, H, 25, 25, 30);
        rasterKernel<<<grid, block>>>(d_tris, numTris, d_fb, d_zb, W, H);
        CUDA_CHECK(cudaMemcpy(framebuffer.data(), d_fb, fbBytes,
                              cudaMemcpyDeviceToHost));
    };

    // ---- warm-up, then timed runs (kernels + device->host copy) --------------
    renderOnce();
    CUDA_CHECK(cudaDeviceSynchronize());

    const int RUNS = 6;
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    float total = 0.f;
    std::printf("\n  run | total time (ms)\n  ----+----------------\n");
    for (int i = 0; i < RUNS; ++i) {
        CUDA_CHECK(cudaEventRecord(start));
        renderOnce();
        CUDA_CHECK(cudaEventRecord(stop));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        total += ms;
        std::printf("   %2d | %8.3f\n", i + 1, ms);
    }
    float avg = total / RUNS;
    std::printf("  ----+----------------\n");
    std::printf("  avg total: %.3f ms  (~%.2f FPS) over %d runs at %dx%d\n",
                avg, 1000.f / avg, RUNS, W, H);

    writeBMP(outPath, W, H, framebuffer.data());
    std::printf("Saved %s\n", outPath.c_str());

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_tris); cudaFree(d_fb); cudaFree(d_zb);
    return 0;
}
