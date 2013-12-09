function c = structab2cell(s)
% Convert a struct table to a cell array
% A struct table with N rows and M fields will be converted to an N-by-M
% cell array, each element containing one item from the table.
% Usage:
%   c = structab2cell(s)
%     The rows of c contain rows from s, and the columns of c contain the
%     fields from s. The columns are ordered according to fieldnames(s).
%     Any fields of s that are cell arrays of strings will be preserved as
%     such in the corresponding column of c. This means that for cell
%     arrays of strings, c{i,j} == s.(f{j}){i}, and for all other types,
%     c{i,j} == s.(f{j})(i,:).

sfields = fieldnames(s);
nfields = numel(sfields);
nrows = size(s.(sfields{1}), 1);

c = cell(nrows, nfields);
for i=1:nfields
    f = s.(sfields{i});
    if iscellstr(f)
        c(:,i) = f;
    else
        fdim = ndims(f);
        c(:,i) = num2cell(f, 2:fdim);
    end
end