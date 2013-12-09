function res = structab_lookup(sdb, field, value)
% Retrieve rows from a table based on one field
% Usage:
%   t = structab_lookup(s, field, value)
%     Returns a struct table containing only the subset of rows where some
%     condition is met on the specified field. The condition depends on the
%     type of value given:
%       string: If the field is a cell array of strings, retrieves those
%               rows where the strings match by strcmp.
%       scalar: Retrieves those rows where the values are equal. The
%               specified field must be a vector.
%       function handle: Calls the function on the field. The function must
%               return an N-by-1 logical array which can be used for
%               indexing the struct table.

if isa(value,'function_handle')
    match = value(sdb.(field));
elseif iscellstr(sdb.(field)) && ischar(value)
    match = strcmp(value, sdb.(field));
elseif isscalar(value) && isvector(sdb.(field))
    match = sdb.(field) == value;
else
    error('Invalid lookup value for specified field.')
end

res = structab_index(s, match);
