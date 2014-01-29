function [s, nonUniform] = cell2structab(c, fields, default, dim)
% Convert a cell array to a struct table
% Sometimes it's useful to deal with tables as cell arrays instead of as
% structs.
% Usage:
%   s = cell2structab(c, fields)
%     Creates a struct table from a cell array of items. If c is an N-by-M
%     cell array, fields must be a cell array of M strings. The resulting
%     table has M fields and N rows. When possible, the fields are
%     vertically concatenated to form an N-by-P(-by-Q-by-R-by...) array;
%     otherwise the fields are left in an N-by-1 cell array. Fields are
%     concatenated when:
%       1. Every element has size(...,1)==1
%       2. The elements are all the same size otherwise
%       3. They are concatenatable types.
%     The exception is if the field contains only strings (i.e.,
%     iscellstr(c{:,i}) is true), it is left as a cell array of strings.
%     Example:
%       >> c = { 'spam', 1, [1 2 3], [1 2];
%                'eggs', 2, [4 5 6], [3 4 5];
%                'milk', 3, [7 8 9], [] };
%       >> fields = {'string','scalar','vector','mixed'};
%       >> table = cell2structab(c, fields)
%       table =
%         string: {'spam'; 'eggs'; 'milk'}
%         scalar: [1; 2; 3]
%         vector: [3x3 double]
%          mixed: {[1 2]; [3 4 5]; []}
%
%   s = cell2structab(c, fields, default)
%     Supply default values for empty fields. default values can be
%     specified as:
%       1. A non-struct, non-cell. All empty fields except for empty
%          strings ('') will be replaced with the default value. E.g., NaN.
%       2. A scalar struct sharing the same fieldnames as supplied in
%          fields. The default values are specified per-field.
%       3. An N-element cell array supplying default value corresponding to
%          the specified fields.
%       4. A scalar cell array, behaving the same as the non-struct scalar
%          for its one contained cell. This lets you e.g. provide a scalar
%          struct as a default if you're so inclined.
%     This allows struct arrays with empty fields to still be concatenated.
%     Example:
%       >> c = {1; []; 3};
%       >> fields = {'scalar'};
%       >> table = cell2structab(c, fields, NaN)
%       table =
%         scalar: [1; NaN; 3]
%   
%   s = cell2structab(c, fields, default, dim)
%     Changes which dimension of c is treated as the field dimension. 2 is
%     the default behavior. size(c,dim) must equal numel(fields).
%   
%   [s, nonUniform] = cell2structab(...)
%     Identifies which fields were unable to be concatenated properly.
%     nonUniform is a 1-by-M logical, where true denotes fields which are
%     kept as cell arrays (and aren't cell arrays of strings). The values
%     in nonUniform correspond to the fields in s according to the order of
%     fieldnames(s).

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
    elseif ~iscell(default)
        default = {default};
    end
    empties = cellfun(@isempty, c);
    charFields = cellfun(@ischar, c);
    if isscalar(default)
        c(empties & ~charFields) = default;
    else
        for i=1:nfields
            c(i,empties(i,:)) = default(i);
        end
    end
end

% % To save us possible headaches from not catching it, verify that all
% % entries have size(...,1) == 1.
% szs = cellfun(@(x)size(x,1), c);
% emptychar = cellfun(@(x)ischar(x)&&isempty(x), c);
% if ~all(szs(:) == 1 | emptychar(:))
%     error('All entries must have size(...,1)==1!');
% end

% Preallocate
s = cell(nfields,1);
nonUniform = false(size(s));
for i=1:nfields
    if iscellstr(c(i,:))
        s{i} = c(i,:)';
    elseif ~catableFieldSizes(c(i,:))
        s{i} = c(i,:)';
        nonUniform(i) = true;
    else
        try
            s{i} = vertcat(c{i,:});
        catch %#ok<CTCH>
            % Concatenation failed for some other reason (nonuniform type,
            % perhaps).
            s{i} = c(i,:)';
            nonUniform(i) = true;
        end
    end
end

s = cell2struct(s, fields, 1);

function tf = catableFieldSizes(c)
nd = cellfun(@ndims, c);
if ~isscalar(unique(nd))
    % Non-uniform dimensionality.
    tf = false;
    return;
end
szs = cellfun(@size, c, 'UniformOutput', false);
szs = unique(vertcat(szs{:}), 'rows');
if ~isrow(szs)
    % Non-uniform sizes.
    tf = false;
    return;
end
if szs(1) ~= 1
    % Fields are not rows.
    tf = false;
    return;
end
% Fields have uniform size and size(...,1)==1.
tf = true;
