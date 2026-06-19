% render.m
function frameBuffer = render(objFilename, mtlFilename, shadingMethod, camera, light)
    % 渲染主函数
    % objFilename, mtlFilename: 模型和材质文件路径
    % shadingMethod: 'flat' | 'gouraud' | 'phong'
    % camera: 结构体，包含 mode, param
    % light: 结构体，包含 direction 等参数

    %=== 读取模型和材质 ===%
    obj = readObj(objFilename);
    materials = readMtl(mtlFilename);
    
    if ~isempty(obj.vt) && isfield(obj.f, 'vt') && ~isempty(obj.f.vt) ...
            && ~isempty(materials) && isfield(materials(1), 'map_Kd') && ~isempty(materials(1).map_Kd)
        vertexColors = vertexColorMapping(obj, materials);  % 使用贴图
    elseif ~isempty(materials) && isfield(materials(1), 'Kd')
        vertexColors = repmat(materials(1).Kd, size(obj.v,1), 1);  % 用材质漫反射色
    else
        vertexColors = repmat([0.5, 0.5, 0.5], size(obj.v,1), 1);  % 兜底灰
    end

    mode = camera.mode;

    %=== 投影 ===%
    projCoords = project(obj.v, mode, camera);  % 使用 camera.mode 区分投影方式

    %=== 屏幕空间变换 ===%
    H = camera.imageHeight;
    W = camera.imageWidth;
    screenCoords = ndcToScreen(projCoords, W, H);

    %=== 初始化 FrameBuffer 和 ZBuffer ===%
    frameBuffer = ones(H, W, 3);
    zBuffer = inf(H, W);

    %=== 着色函数选择 ===%
    switch lower(shadingMethod)
        case 'flat'
            shadingFunc = @flatShading;
        case 'gouraud'
            shadingFunc = @gouraudShading;
        case 'phong'
            shadingFunc = @phongWrapper;
        otherwise
            error('Unsupported shading method: %s', shadingMethod);
    end

    %=== 三角形光栅化 ===%
    for i = 1:size(obj.f.v, 1)
        vidx = obj.f.v(i, :);              % 顶点索引
        vtx_screen = screenCoords(vidx, :);
        vtx_color = vertexColors(vidx, :);
        vtx_normal = obj.vn(obj.f.vn(i,:), :);
        vtx_pos = obj.v(vidx, :);
        
        [frameBuffer, zBuffer] = rasterizeTriangle( ...
            frameBuffer, zBuffer, ...
            vtx_screen, vtx_color, vtx_normal, vtx_pos, ...
            shadingFunc, light.direction, camera.viewDir, ...
            light.ka, light.kd, light.ks, light.shininess ...
        );
    end

end