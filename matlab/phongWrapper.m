function color = phongWrapper(vertexColors, vertexNormals, vertexPositions, baryCoord, lightDir, viewDir, ka, kd, ks, shininess)
    normal = normalizeVec(baryCoord * vertexNormals);
    position = baryCoord * vertexPositions;
    baseColor = baryCoord * vertexColors;
    
    color = unifiedLighting(position, normal, baseColor, lightDir, viewDir, ka, kd, ks, shininess);
end
