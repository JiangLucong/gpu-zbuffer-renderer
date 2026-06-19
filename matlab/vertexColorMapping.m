function vertex_colors = vertexColorMapping(obj, mtl)
%VERTEXCOLORMAPPING Maps vertex texture coordinates to RGB values.
%   VERTEX_COLORS = VERTEXCOLORMAPPING(OBJ, MTL)
%   returns the RGB colors for each vertex in OBJ, using the texture
%   defined in the associated MTL structure.
%
%   INPUT:
%       obj - struct from readObj(), must contain vt and f.vt
%       mtl - struct array from readMtl(), must contain map_Kd
%
%   OUTPUT:
%       vertex_colors - Nx3 array, each row is [R G B] for one vertex

% Handle the case with no texture
if isempty(obj.vt) || isempty(obj.f.vt) || isempty(mtl) || isempty(mtl(1).map_Kd)
    warning('No texture mapping data found. Using default gray color.');
    vertex_colors = repmat([0.5, 0.5, 0.5], size(obj.v,1), 1);
    return;
end

% Assume single material for now
tex_file = mtl(1).map_Kd;
img = im2double(imread(tex_file));
[h, w, c] = size(img);

% Get per-face vt indices, then map to uv coordinates
vt_idx = obj.f.vt(:);
uv = obj.vt(vt_idx, :);

% Convert to pixel coordinates (assuming origin at bottom-left)
x = round(uv(:,1) * (w - 1)) + 1;
y = round((1 - uv(:,2)) * (h - 1)) + 1; % flip y-axis

% Clamp to valid range
x = min(max(x, 1), w);
y = min(max(y, 1), h);

% Get colors from texture
if c == 3
    r = img(sub2ind([h, w], y, x));
    g = img(sub2ind([h, w], y, x) + h*w);
    b = img(sub2ind([h, w], y, x) + 2*h*w);
    colors = [r, g, b];
else
    gray = img(sub2ind([h, w], y, x));
    colors = repmat(gray, 1, 3);
end

% Assign one color per vertex (average if duplicated)
vertex_colors = zeros(size(obj.v,1), 3);
counts = zeros(size(obj.v,1), 1);

for i = 1:numel(obj.f.v)
    vid = obj.f.v(i);
    vertex_colors(vid, :) = vertex_colors(vid, :) + colors(i, :);
    counts(vid) = counts(vid) + 1;
end

% Normalize by counts
counts(counts == 0) = 1;
vertex_colors = vertex_colors ./ counts;
end
