function s = cell2structab(c, fields, default, dim)
% Convert a cell array to a struct table
% Usage:
%   s = cell2structab(c, fields)
%     If c is an N-by-M cell array, and fields is a cell array of strings
%     with M elements, creates a struct table with N rows in M fields. Each
%     element in c must have size(...,1)==1. If c is higher dimension than
%     2, extra dimensions will be wrapped into extra rows. Any columns that
%     contain only strings will be kept as cell arrays of strings in the
%     resulting struct; any other type will be vertically concatenated.
%     This means that for cell arrays of strings, s.(fields{j}){i} ==
%     c{i,j}, and for all other types, s.(fields{j})(i,:) == c{i,j}.
%   s = cell2structab(c, fields, default)
%     default can be either a cell array with M entries, or a struct with
%     fields matching the specified fields. All cells containing empty
%     arrays will be replaced with the value for the corresponding field in
%     default before concatenation.
%   s = cell2structab(c, fields, default, dim)
%     As above, but treats dim as the dimension corresponding to fields.

if ~exist('dim','var') || isempty(dim)
    dim = 2;
end

nfields = size(c, dim);
if nfields ~= numel(fields)
    error('Number of fields does not match number of names');
end
% Rearrange c to N-by-M
dar = 1:ndims(c);
dar([1 dim]) = dar([dim 1]);
c = permute(c, dar);
c = reshape(c, nfields, []);

if exist('default','var') && ~isempty(default)
    if isstruct(default)
        default = orderfields(default, fields);
        default = struct2cell(default);
    end
    empties = cellfun(@isempty, c);
    for i=1:nfields
        c(i,empties(i,:)) = default(i);
    end
end

% To save us possible headaches from not catching it, verify that all
% entries have size(...,1) == 1.
szs = cellfun(@(x)size(x,1), c);
if ~all(szs(:) == 1)
    error('All entries must have size(...,1)==1!');
end

% Preallocate
s = cell(nfields,1);

for i=1:nfields
    if iscellstr(c(i,:))
        s{i} = c(i,:)';
    else
        s{i} = vertcat(c{i,:});
    end
end

s = cell2struct(s, fields, 1);