function color = phongShading(vertexNormals, vertexPositions, baryCoord, lightDir, viewDir, ka, kd, ks, shininess, vertexColors)
% Phong 着色（Blinn-Phong 模型）调用 computeLighting
% 输入参数说明与原函数相同

    % 重心插值：法线、位置、基础色
    N = normalizeVec(...
        baryCoord(1)*vertexNormals(1,:) + ...
        baryCoord(2)*vertexNormals(2,:) + ...
        baryCoord(3)*vertexNormals(3,:));

    pos = ...
        baryCoord(1)*vertexPositions(1,:) + ...
        baryCoord(2)*vertexPositions(2,:) + ...
        baryCoord(3)*vertexPositions(3,:);

    baseColor = ...
        baryCoord(1)*vertexColors(1,:) + ...
        baryCoord(2)*vertexColors(2,:) + ...
        baryCoord(3)*vertexColors(3,:);

    % 封装材质
    material.Kd = kd .* baseColor;
    material.Ks = ks;
    material.Ns = shininess;

    % 封装光源（假设是方向光，方向已给定，位置可以是远处）
    light.position = pos + lightDir * 1000;  % 方向光用远点模拟
    light.color = [1, 1, 1];
    light.intensity = 1.0;

    % 环境光直接加（你原来的 ka * baseColor）
    ambient = ka .* baseColor;

    % 调用 computeLighting
    color = ambient + computeLighting(pos, N, viewDir, light, material);

    % 限制 [0,1]
    color = min(max(color, 0), 1);
end

function v = normalizeVec(v)
    v = v / norm(v + 1e-8);
end
