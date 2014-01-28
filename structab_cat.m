function tab = structab_cat(tabarr)
% Concatenate an array of structs into a single structab table
% Usage:
%   tab = structab_cat(tabarr)
%     tabarr is an array of structs where each element is presumed to be a
%     structab table which are to have all their fields concatenated.
% Example:
%   Suppose x and y are structab tables with identical fields, x having M
%   rows and y having N rows.
%       tab = structab_cat([x y])
%   will produce a new structab tab with the same fields as x and y, having
%   M+N rows.

fnames = fieldnames(tabarr);
tab = struct;
for i=1:numel(fnames)
    tab.(fnames{i}) = vertcat(tabarr.(fnames{i}));
end