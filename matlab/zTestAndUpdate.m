function [pass, zBuffer] = zTestAndUpdate(zBuffer, x, y, z)
if z < zBuffer(y, x)
    zBuffer(y, x) = z;
    pass = true;
else
    pass = false;
end
end
