function A = normalizeRows(A)
    A = A ./ vecnorm(A, 2, 2);
end
