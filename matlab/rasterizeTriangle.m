function [frameBuffer, zBuffer] = rasterizeTriangle(frameBuffer, zBuffer, vertices, colors, normals, positions, shadingFunc, lightDir, viewDir, ka, kd, ks, shininess)
[h, w, ~] = size(frameBuffer);
minX = max(floor(min(vertices(:,1))), 1);
maxX = min(ceil(max(vertices(:,1))), w);
minY = max(floor(min(vertices(:,2))), 1);
maxY = min(ceil(max(vertices(:,2))), h);
v0 = vertices(2,:) - vertices(1,:);
v1 = vertices(3,:) - vertices(1,:);
denom = v0(1)*v1(2) - v1(1)*v0(2);
for y = minY:maxY
    for x = minX:maxX
        p = [x + 0.5, y + 0.5];
        v2 = p - vertices(1,1:2);
        a = (v2(1)*v1(2) - v1(1)*v2(2)) / denom;
        b = (v0(1)*v2(2) - v2(1)*v0(2)) / denom;
        c = 1 - a - b;
        if a >= 0 && b >= 0 && c >= 0
            baryCoord = [a, b, c];
            z = baryCoord * vertices(:,3);
            [pass, zBuffer] = zTestAndUpdate(zBuffer, x, y, z);
            if pass
                color = shadingFunc(colors, normals, positions, baryCoord, lightDir, viewDir, ka, kd, ks, shininess);
                frameBuffer(y, x, :) = color;
            end
        end
    end
end
end
