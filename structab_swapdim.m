function [s, d] = structab_swapdim(s, d)
% Swap a higher dimension for the first for all fields in a struct
% Usage:
%   s = structab_swapdim(s, d)
%     Swaps the dimension d into the first dimension for all fields of s.
%     This can allow other structab functions to operate on that dimension
%     as rows of the table.
%   [s, d] = structab_swapdim(s)
%     Guesses d, the lowest dimension suitable to serve as the row index
%     for a table. This is done by comparing the sizes of all fields and
%     finding dimensions that are (1) the same for all fields, and (2) not
%     1. Then swaps that dimension for the first dimension, as above.
%     Calling structab_swapdim(s,d) subsequently will reverse the
%     operation; this is a bit like using shiftdim on normal arrays to
%     operate on the lowest non-singleton dimension.

field_ds = structfun(@ndims, s);
min_d = min(field_ds);
max_d = max(field_ds);

if ~exist('d','var') || isempty(d)
    field_sz = cellfun(@size, struct2cell(s), 'UniformOutput', false);
    compare_sz = cellfun(@(x)x(1:min_d), field_sz, 'UniformOutput', false);
    compare_sz = vertcat(compare_sz{:});
    is_same = all(bsxfun(@eq, compare_sz, compare_sz(1,:)));
    is_nonsingle = compare_sz(1,:) ~= 1;
    d = find(is_same & is_nonsingle, 1);
    if isempty(d)
        % No suitable dimensions were found.
        d = 0;
        return;
    end
end

dvec = 1:max_d;
dvec([1 d]) = dvec([d 1]);

sf = fieldnames(s);
for i=1:numel(sf)
    s.(sf{i}) = permute(s.(sf{i}), dvec);
end
