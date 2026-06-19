function color = unifiedLighting(position, normal, baseColor, lightDir, viewDir, ka, kd, ks, shininess)
    normal = normalizeVec(normal);
    viewDir = normalizeVec(viewDir);
    lightDir = normalizeVec(lightDir);

    % 判断是否朝向光源
    diffuseFactor = max(dot(normal, lightDir), 0);

    if diffuseFactor <= 0
        % 背光，只保留环境光
        color = ka .* baseColor;
    else
        L = lightDir;
        V = viewDir;
        H = normalizeVec(L + V);

        ambient = ka .* baseColor;
        diffuse = kd .* baseColor * diffuseFactor;
        specular = ks * (max(dot(normal, H), 0) ^ shininess);

        color = ambient + diffuse + specular;
    end
end
