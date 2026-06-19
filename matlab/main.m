clc; clear;

%=== 模型文件名 ===%
objFilename = 'objs/monkey_cork.obj';    % 替换为你的 .obj 文件
mtlFilename = 'objs/monkey_cork.mtl';    % 替换为你的 .mtl 文件

%=== 选择着色方法：flat / gouraud / phong ===%
shadingMethod = 'phong';

%=== 摄像机设置 ===%
camera = struct( ...
    'cameraPos', [0, 0, 5], ...
    'lookAt', [0, 0, 0], ...
    'up', [0, 1, 0], ...
    'fov', 45, ...
    'aspect', 1.0, ...
    'near', 1.0, ...
    'far', 1000.0, ...
    'imageWidth', 1024, ...
    'imageHeight', 1024, ...
    'mode', 'perspective', ...
    'viewDir', normalizeVec([0, 0, -1]) ...
);

%=== 光源设置（平行光） ===%
light = struct( ...
    'direction', normalizeVec([0.5, -1, -0.5]), ...
    'ka', [0.5, 0.5, 0.5], ...
    'kd', [1, 1, 1], ...
    'ks', [0.5, 0.5, 0.5], ...
    'shininess', 32 ...
);

%=== 调用渲染函数 + 记录渲染耗时 ===%
tic;
frame = render(objFilename, mtlFilename, shadingMethod, camera, light);
elapsedTime = toc;
fprintf('渲染耗时：%.3f 秒\n', elapsedTime);

%=== 显示结果 ===%
imshow(frame, 'InitialMagnification', 'fit');  % 自动适配窗口
title(['Shading: ', shadingMethod], 'FontSize', 14);

%=== 保存结果 ===%
imwrite(frame, 'render_output.png');             % 保存为PNG文件

%=== 亮度梯度与高光区域统计 ===%
grayFrame = rgb2gray(frame);

% 设置更高的高光检测阈值（方案1）
highlightThreshold = 0.95;
highlightMask = grayFrame > highlightThreshold;

% 计算全图平均亮度梯度（仅用于参考）
[Gx, Gy] = imgradientxy(grayFrame, 'sobel');
gradientMagnitude = sqrt(Gx.^2 + Gy.^2);
avgGlobalGradient = mean(gradientMagnitude(:));

% 只在高光区域附近计算局部亮度梯度（方案2）
if any(highlightMask(:))
    localGradients = gradientMagnitude(highlightMask);
    avgHighlightGradient = mean(localGradients);
else
    avgHighlightGradient = 0;
end

% 统计高光区域数量和平均面积
cc = bwconncomp(highlightMask);
highlightCount = cc.NumObjects;
if highlightCount > 0
    highlightAreas = cellfun(@numel, cc.PixelIdxList);
    avgHighlightArea = mean(highlightAreas);
else
    avgHighlightArea = 0;
end

%=== 输出统计结果 ===%
fprintf('全图平均亮度梯度：%.3f\n', avgGlobalGradient);
fprintf('高光区域数量：%d，平均面积：%.1f 像素\n', highlightCount, avgHighlightArea);
fprintf('高光区域局部平均亮度梯度：%.3f\n', avgHighlightGradient);
