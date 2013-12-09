function s = structab_index(s, ind)
% Retrieve a subset of rows from a table
% Usage:
%   t = structab_index(s, ind)
%     Uses ind to index the first dimension of every field in s, such that
%     t.field = s.field(ind,:,:,:,...).

fnames = fieldnames(s);
sub.type = '()';
subsBase = {':', ind};
for i=1:numel(fnames)
    curValue = s.(fnames{i});
    % Make the (ind,:,:,:,...) subscript:
    sub.subs = subsBase([2 ones(1, ndims(curValue)-1)]);
    s.(fnames{i}) = subsref(curValue, sub);
end