function sarr = structab2arr(stab)

c = structab2cell(stab);
sarr = cell2struct(c, fieldnames(stab), 2);