% project.m
function projected = project(vertices, mode, params)
    switch lower(mode)
        case 'perspective'
            projected = perspectiveProject(vertices, params);
        case 'orthographic'
            projected = orthographicProject(vertices, params);
        otherwise
            error('Unsupported projection mode: %s', mode);
    end
end
