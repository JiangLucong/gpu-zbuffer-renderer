function screenCoord = ndcToScreen(ndcCoords, width, height)
    % 提取 x, y 分量
    x_ndc = ndcCoords(:,1);
    y_ndc = ndcCoords(:,2);
    
    % 映射公式
    x_screen = (x_ndc + 1) * (width - 1) / 2;
    y_screen = (1 - y_ndc) * (height - 1) / 2;

    % 如果有 z，就也转
    if size(ndcCoords, 2) == 3
        z_ndc = ndcCoords(:,3);
        z_screen = (z_ndc + 1) / 2;  % 映射到 [0, 1]
        screenCoord = [x_screen, y_screen, z_screen];
    else
        screenCoord = [x_screen, y_screen];
    end
end
