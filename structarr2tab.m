function stab = structarr2tab(sarr, defaults)
% Convert an array of struct into a scalar struct table
% Both struct arrays and scalar structs with parallel fields are useful for
% representing tables, depending on the requirements. This converts from an
% array to a scalar table.
% Usage:
%   stab = structarr2tab(sarr)
%     Fields of sarr are concatenated vertically to form the fields of
%     stab. That is, stab.field = vertcat(sarr.field), for each field.
%     Elements from corresponding fields must be concatenatable, and if
%     size(...,1)~=1 for any of them, the operation will fail.
%   stab = structarr2tab(sarr, defaults)
%     defaults is a scalar struct having the same fields as sarr. If any
%     fields of any elements of sarr are empty, they will be replaced with
%     the corresponding field from defaults. This allows missing values to
%     be handled more gracefully (e.g., supply a NaN).

if ~exist('defaults', 'var')
    defaults = [];
end

stab = cell2structab(struct2cell(sarr), fieldnames(sarr), defaults, 1);
