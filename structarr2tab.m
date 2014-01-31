function [stab, nonUniform] = structarr2tab(sarr, default)
% Convert an array of struct into a scalar struct table
% Both struct arrays and scalar structs with parallel fields are useful for
% representing tables, depending on the requirements. This converts from an
% array to a scalar table.
% Usage:
%   stab = structarr2tab(sarr)
%     Fields of sarr are concatenated vertically to form the fields of
%     stab. That is, stab.field = vertcat(sarr.field), for each field.
%     There are two exceptions:
%       1. If iscellstr({sarr.field}) (that is, all elements of the field
%          are strings), then stab.field = {sarr.field}' (that is, the
%          field is represented as a cell array of strings).
%       2. If vertical concatenation is not possible, or if
%          size(sarr(i).field, 1) ~= 1 for any elements, then the field is
%          stored as a cell array instead (stab.field = {sarr.field}').
%          This is primarily to permit a graceful failure mode for
%          improperly structured data.
%     Example:
%       >> sarr = repmat(struct, 3, 1);
%       >> [sarr.string] = deal('spam', 'eggs', 'milk');
%       >> [sarr.scalar] = deal(1, 2, 3);
%       >> [sarr.vector] = deal(1:3, 4:6, 7:9);
%       >> [sarr.mixed] = deal([1 2], [3 4 5], [])
%       sarr = <3x1 struct with fields string, scalar, vector, mixed>
%       >> stab = structarr2tab(sarr)
%       stab =
%         string: {'spam'; 'eggs'; 'milk'}
%         scalar: [1; 2; 3]
%         vector: [3x3 double]
%          mixed: {[1 2]; [3 4 5]; []}
%       
%   stab = structarr2tab(sarr, defaults)
%     Supplies a default value for "missing" data (when the field is
%     empty). Can be supplied in two ways:
%       1. A non-struct, non-cell. All empty field values which are not
%          empty strings ('') will be replaced by the default value.
%       2. A scalar struct with fields corresponding to the ones in sarr.
%          The default values are then applied field-wise.
%     (Actually, other options are possible, see cell2structab if curious.)
%     Example:
%       >> sarr(1).scalar = 1;
%       >> sarr(2).scalar = [];
%       >> sarr(3).scalar = 3;
%       >> stab = structarr2tab(sarr, NaN)
%       stab =
%         scalar: [1; NaN; 3]
%   
%   [stab, nonUniform] = structarr2tab(...)
%     Identifies which fields were unable to be concatenated properly.
%     nonUniform is a 1-by-M logical, where true denotes fields which are
%     kept as cell arrays (and aren't cell arrays of strings). The values
%     in nonUniform correspond to the fields in stab according to the order
%     of fieldnames(stab).

if ~exist('default', 'var')
    default = [];
end

[stab, nonUniform] = cell2structab(struct2cell(sarr), fieldnames(sarr), ...
    default, 1);
