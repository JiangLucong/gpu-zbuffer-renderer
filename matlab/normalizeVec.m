function v = normalizeVec(v)
    v = v / norm(v + 1e-8);
end
