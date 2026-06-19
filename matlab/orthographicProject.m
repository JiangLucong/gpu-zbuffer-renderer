% orthographicProject.m
function projected = orthographicProject(vertices, params)
    % 参数读取
    left   = params.left;
    right  = params.right;
    bottom = params.bottom;
    top    = params.top;
    near   = params.near;
    far    = params.far;
    eye    = params.cameraPos(:);
    target = params.lookAt(:);
    up     = params.up(:);

    % 构建视图矩阵（LookAt，同 perspective）
    z = normalize(eye - target);   % forward
    x = normalize(cross(up, z));   % right
    y = cross(z, x);               % up
    viewMat = [x, y, z, -[x, y, z]*eye;
               0, 0, 0, 1];

    % 构建正交投影矩阵（OpenGL 风格）
    projMat = [2/(right-left), 0, 0, -(right+left)/(right-left);
               0, 2/(top-bottom), 0, -(top+bottom)/(top-bottom);
               0, 0, -2/(far-near), -(far+near)/(far-near);
               0, 0, 0, 1];

    % 顶点变换
    V = [vertices, ones(size(vertices,1),1)];
    V_camera = (viewMat * V')';
    V_clip = (projMat * V_camera')';

    % 齐次除法，得到 NDC 空间
    projected = V_clip(:,1:3) ./ V_clip(:,4);
end

function v = normalize(v)
    v = v / norm(v);
end
