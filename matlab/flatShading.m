function color = flatShading(vertexColors, vertexNormals, vertexPositions, baryCoord, lightDir, viewDir, ka, kd, ks, shininess)
    center = mean(vertexPositions, 1);
    normal = normalizeVec(mean(vertexNormals, 1));
    baseColor = mean(vertexColors, 1);
    
    color = unifiedLighting(center, normal, baseColor, lightDir, viewDir, ka, kd, ks, shininess);
end
