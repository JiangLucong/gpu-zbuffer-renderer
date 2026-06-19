function materials = readMtl(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open MTL file: %s', filename);
    end

    % 明确初始化所有字段，避免结构体字段不一致
    default = struct('name', '', 'Ka', [], 'Kd', [], 'Ks', [], ...
                     'Ns', [], 'map_Kd', '', 'texture', []);
    materials = default([]);  % 正确初始化 struct 数组
    current = default;        % 每次拷贝一个新的

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line) || startsWith(line, '#')
            continue;
        end

        tokens = regexp(line, '(\S+)\s+(.*)', 'tokens');
        if isempty(tokens)
            continue;
        end
        key = tokens{1}{1};
        valueStr = strtrim(tokens{1}{2});

        switch key
            case 'newmtl'
                if ~isempty(current.name)
                    materials(end+1) = current; %#ok<AGROW>
                end
                current = default;  % 拷贝一个干净的模板
                current.name = valueStr;

            case 'Ka'
                current.Ka = sscanf(valueStr, '%f')';

            case 'Kd'
                current.Kd = sscanf(valueStr, '%f')';

            case 'Ks'
                current.Ks = sscanf(valueStr, '%f')';

            case 'Ns'
                current.Ns = str2double(valueStr);

            case 'map_Kd'
                current.map_Kd = valueStr;
                if exist(current.map_Kd, 'file')
                    try
                        current.texture = im2double(imread(current.map_Kd));
                    catch
                        warning('无法读取贴图图像：%s', current.map_Kd);
                        current.texture = [];
                    end
                else
                    warning('Texture file %s not found.', current.map_Kd);
                    current.texture = [];
                end
        end
    end

    % 最后一个材质也要添加
    if ~isempty(current.name)
        materials(end+1) = current;
    end

    fclose(fid);
end
