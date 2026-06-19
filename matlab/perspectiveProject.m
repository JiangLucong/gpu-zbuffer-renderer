% perspectiveProject.m
function projected = perspectiveProject(vertices, params)
    % 参数读取
    eye = params.cameraPos(:);   % 3x1
    target = params.lookAt(:);
    up = params.up(:);
    fov = params.fov;            % 单位：度
    aspect = params.aspect;
    near = params.near;
    far = params.far;

    % LookAt视图矩阵（右手坐标系）
    z = normalize(eye - target);          % forward
    x = normalize(cross(up, z));          % right
    y = cross(z, x);                      % up
    viewMat = [x, y, z, -[x, y, z]*eye;   % R | -R*eye
               0, 0, 0, 1];

    % 透视投影矩阵（右手坐标系，OpenGL风格）
    f = 1 / tan(deg2rad(fov) / 2);
    projMat = [f/aspect, 0, 0, 0;
               0, f, 0, 0;
               0, 0, (far+near)/(near-far), (2*far*near)/(near-far);
               0, 0, -1, 0];

    % 顶点齐次化并变换
    V = [vertices, ones(size(vertices,1),1)]; % Nx4
    V_camera = (viewMat * V')';              % 先乘视图
    V_clip = (projMat * V_camera')';         % 再乘投影

    % 齐次除法，得到 NDC
    projected = V_clip(:,1:3) ./ V_clip(:,4);

    % 可选：保留裁剪空间W分量做后续处理
    % projected = struct('ndc', projected, 'clip_w', V_clip(:,4));
end

function v = normalize(v)
    v = v / norm(v);
end
