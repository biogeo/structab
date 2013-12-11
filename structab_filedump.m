function output = structab_filedump(s, file, varargin)
% Dump a struct table to a text file.
% The main use case of this function is to prepare a file suitable for use
% with MySQL's LOAD DATA INFILE command, in order to transfer the struct
% table to a real SQL table quickly (because let's face it, Matlab doesn't
% do tables well).
% Usage:
%   file = structab_filedump(s)
%     Creates a temporary file (as selected by a call to tempname) and
%     dumps the data in s to the file, returning the filename.
%   structab_filedump(s, file)
%     Writes the data in s to the specified file, overwriting the existing
%     file.
%   structab_filedump(s, fid)
%     Writes the data to the file identifier fid. 1 is good for testing
%     purposes.
%   structab_filedump(..., formats)
%     Specify format strings for each column. Formats can be either a cell
%     array or a struct with the same field names as s, where each element
%     gives a format string for the corresponding field in s, of the type
%     appropriate for passing to *printf functions. If not specified,
%     string fields will be formatted with '%s', and numerics with '%g'.
%   structab_filedump(...,'Parameter',value)
%     Specify optional parameters:
%       NullOutput: What will be written for missing/null values. Default
%           '\N'.
%       NansAreNull: Whether to treat NaN values as null. Default true.
%       NullString: Elements in string fields with this value will be
%           treated as null, or false for no null values. Default false.
%       FieldDelim: The string to insert between fields. Formatting escape
%           sequences are parsed. Default '\t' (tab).
%       RowDelim: The string to insert between rows. Formatting escape
%           sequences are parsed. Default '\n' (newline).
%       EscapeDelims: Whether to escape FieldDelim and RowDelim when they
%           are found in string fields. Default true. Setting false could
%           give a small speed boost if you know these delimiters are
%           absent from your data.
% 
% At the moment, ONLY fields which are cell arrays of strings or numeric
% vectors are permitted. Any other types will fail.
% 
% Note:
%   To handle replacing NaNs with the null string, numeric arrays are
%   preprocessed with num2str instead of sending directly to fprintf. The
%   end result is that formatting field widths for numeric data are not
%   necessarily respected. Since this is immaterial for my use case
%   (dumping files for SQL input), I don't regard this as a bug and I won't
%   bother to "fix" it, but it is worth noting should my future needs
%   change, or someone else be using this code.

fields = fieldnames(s);
s = struct2cell(s); % Make it easier to iterate.
nfields = numel(fields);
nrows = size(s{1},1);
is_field_string = cellfun(@iscellstr, s);
is_field_numeric = cellfun(@isnumeric, s);
is_field_vector = cellfun(@isvector, s);
if ~all(is_field_vector) && all(is_field_string | is_field_numeric)
    error('Unrecognized field type.');
end
default_formats = cell(size(s));
default_formats(is_field_string) = {'%s'};
default_formats(is_field_numeric) = {'%g'};

p = inputParser;
p.addOptional('Format', default_formats);
p.addParamValue('NullOutput', '\N');
p.addParamValue('NansAreNull', true);
p.addParamValue('NullString', false);
p.addParamValue('FieldDelim', sprintf('\t'));
p.addParamValue('RowDelim', sprintf('\n'));
p.addParamValue('EscapeDelims', true);
p.parse(varargin{:});
opts = p.Results;
if isempty(opts.Format)
    % Allow the user to supply an empty matrix to get defaults as well
    opts.Format = default_formats;
elseif isstruct(opts.Format)
    % Convert it to a cell array for easier usage.
    opts.Format = orderfields(opts.Format, fields);
    opts.Format = struct2cell(opts.Format);
end

% Convert the table to a cell array of strings

c = cell(nfields, nrows);
for i=1:nfields
    if is_field_string(i)
        c(i,:) = s{i}';
        if ischar(opts.NullString)
            % Replace NullString values with NullOutput
            c(i,strcmp(opts.NullString, s{i})') = {opts.NullOutput};
        end
    else % field is numeric per error test above
        if opts.NansAreNull
            c(i,:) = num2cellstr(s{i}, opts.Format{i}, opts.NullOutput)';
        else
            c(i,:) = num2cellstr(s{i}, opts.Format{i})';
        end
        opts.Format{i} = '%s'; % How to use the already-formatted string
    end
end

% Escape field or row delimiters within the fields
if opts.EscapeDelims
    c = strrep(c, opts.FieldDelim, ['\' opts.FieldDelim]);
    c = strrep(c, opts.RowDelim, ['\', opts.RowDelim]);
    % Note that strrep is a bit faster (factor of 2 or so on my test) than
    % regexprep for this usage.
end

% Build the format string as:
%   [Format{1} FieldDelim Format{2} FieldDelim ... Format{end} RowDelim]
allFormats = cell(2, nfields);
allFormats(1,:) = opts.Format(:)';
allFormats(2,1:end-1) = {opts.FieldDelim};
allFormats(2,end) = {opts.RowDelim};
formatStr = [allFormats{:}];

if ~exist('file','var') || isempty(file)
    % No filename or identifier was supplied, so use a temp file
    file = tempname;
end
if ischar(file)
    % Open a new file for writing
    opened_file = true;
    fid = fopen(file, 'wt');
elseif isnumeric(file) && isscalar(file)
    % Dump to an already open file
    opened_file = false;
    fid = file;
else
    error('Bad file name or identifier.');
end

try
    % Write the table to file
    fprintf(fid, formatStr, c{:});
catch e
    if opened_file
        fclose(fid);
    end
    rethrow(e);
end

if opened_file
    fclose(fid);
end

if nargout || nargin < 2
    % Return an output only if requested, to make structab_filedump(s,1)
    % look prettier.
    output = file;
end