function obj = readObj(fname)
%READOBJ Reads a Wavefront OBJ file (.obj) and returns geometry data.
%   OBJ = READOBJ(FNAME) parses vertex positions, texture coordinates,
%   normal vectors, and face indices from the .obj file. Faces with more
%   than 3 vertices are automatically triangulated.
%
%   OUTPUT:
%       obj.v  - Nx3 array of vertex coordinates
%       obj.vt - Mx2 array of texture coordinates
%       obj.vn - Kx3 array of normal vectors
%       obj.f  - struct with fields:
%           .v  - Fx3 vertex indices
%           .vt - Fx3 texture coordinate indices
%           .vn - Fx3 normal vector indices

fid = fopen(fname);
if fid == -1
    error('Failed to open file: %s', fname);
end

v = [];
vt = [];
vn = [];
f.v = [];
f.vt = [];
f.vn = [];

while ~feof(fid)
    tline = strtrim(fgetl(fid));
    if isempty(tline) || startsWith(tline, '#')
        continue;
    end

    tokens = strsplit(tline);
    prefix = tokens{1};
    args = tokens(2:end);

    switch prefix
        case 'v'
            v = [v; str2double(args)];
        case 'vt'
            vt = [vt; str2double(args(1:min(2,end)))];
        case 'vn'
            vn = [vn; str2double(args)];
        case 'f'
            [fv, fvt, fvn] = parseFaceLine(args);
            [fv, fvt, fvn] = triangulateFace(fv, fvt, fvn);
            f.v  = [f.v; fv];
            f.vt = [f.vt; fvt];
            f.vn = [f.vn; fvn];
    end
end

fclose(fid);

obj.v = v;
obj.vt = vt;
obj.vn = vn;
obj.f = f;
end

function [fv, fvt, fvn] = parseFaceLine(faceStrList)
% Parses a list of face vertex strings into index arrays
fv = [];
fvt = [];
fvn = [];

for i = 1:length(faceStrList)
    parts = strsplit(faceStrList{i}, '/');
    fv(end+1)  = str2double(parts{1});

    if length(parts) > 1 && ~isempty(parts{2})
        fvt(end+1) = str2double(parts{2});
    else
        fvt(end+1) = NaN;
    end

    if length(parts) > 2 && ~isempty(parts{3})
        fvn(end+1) = str2double(parts{3});
    else
        fvn(end+1) = NaN;
    end
end
end

function [fvT, fvtT, fvnT] = triangulateFace(fv, fvt, fvn)
% Converts n-gon face indices into a list of triangles using fan method
n = length(fv);
if n < 3
    error('Invalid face with less than 3 vertices.');
elseif n == 3
    fvT  = fv;
    fvtT = fvt;
    fvnT = fvn;
    return;
end

fvT = [];
fvtT = [];
fvnT = [];
for i = 2:n-1
    fvT  = [fvT;  fv(1),  fv(i),  fv(i+1)];
    fvtT = [fvtT; fvt(1), fvt(i), fvt(i+1)];
    fvnT = [fvnT; fvn(1), fvn(i), fvn(i+1)];
end
end
