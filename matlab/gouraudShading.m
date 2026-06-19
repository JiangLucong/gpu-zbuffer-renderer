function color = gouraudShading(vertexColors, vertexNormals, vertexPositions, baryCoord, lightDir, viewDir, ka, kd, ks, shininess)
    lightedColors = zeros(3, 3);
    for i = 1:3
        lightedColors(i,:) = unifiedLighting(vertexPositions(i,:), vertexNormals(i,:), vertexColors(i,:), ...
                                              lightDir, viewDir, ka, kd, ks, shininess);
    end
    color = baryCoord * lightedColors;
end
