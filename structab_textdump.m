function output = structab_textdump(s, varargin)
% Dump a struct table to text.
% This function formats the data in a struct table into text. There are a
% few limitations:
%   1. Each field should have one value per row (i.e., be a column vector).
%   2. Fields can only be cell arrays of strings, numeric, or logical.
% The main use case is for export to other systems (in particular MySQL).
% Usage:
%   text = structab_textdump(s)
%     Returns a string with the data in the struct table s formatted. Each
%     row in the table is formatted with the format string:
%       <f1>\t<f2>\t<f3>\t...<fn>\n
%     where the <fi> are selected according to the type of the field:
%       cell array of strings: '%s'
%       integer or logical: '%d'
%       double: '%.17g' (17 is the maximum number of digits needed)
%       single: '%.9g' (9 is the maximum number of digits needed)
%     so that the fields are delimited by tabs and rows by newlines.
%   
%   structab_textdump(s, file)
%     Writes the text to a file instead. file can be a file identifier
%     returned by fopen, or a file name. In the latter case, the file is
%     written to in append mode (and is created if it does not exist).
%   structab_textdump(..., 'Parameter', value, ...)
%     Specify values for optional parameters. Valid parameters are:
%       FieldDelim: A string which delimits fields. (Note that this string
%           will not be further parsed by *printf, so special characters
%           like tab should be literally specified.) Default is tab.
%       RowDelim: A string with delimits rows. (The same caveat applies as
%           above.) Default is newline.
%       FieldQuote: A string which is inserted immediately before and after
%           each field value (like a quote mark). (The same caveat applies
%           as above.) Default is empty string ('').
%       EscapeDelims: True/false; if true, all string fields will be
%           searched for occurrences of the FieldDelim, RowDelim, or
%           FieldQuote characters, or \, and \ will be inserted before
%           them to prevent parsers from treating them as delimiters. (Note
%           that for unusual choices of these strings, such as 'n' or 't',
%           this could lead to unexpected behavior.) If the input data is
%           known not to contain these sequences, setting to false could
%           give a moderate speed boost.

p = inputParser;
p.addOptional('file', [], ...
    @(x)isempty(x)||(isnumeric(x)&&isscalar(x))||ischar(x));
p.addParamValue('FieldDelim', sprintf('\t'), @ischar);
p.addParamValue('FieldQuote', '', @ischar);
p.addParamValue('RowDelim', sprintf('\n'), @ischar);
p.addParamValue('EscapeDelims', true, @islogical);
p.addParamValue('LinePrefix', '', @ischar);
% These could be additional options that might be nice to implement
% eventually:
%p.addParamValue('NumericPrecision', 17);
%p.addParamValue('FieldHeaders', false); % Display a header w/ field names
%p.addParamValue('HeadersPrefix', ''); % Beginning of header line
p.parse(varargin{:});
opts = p.Results;
file = opts.file;

f = fieldnames(s);
col_fields = structfun(@iscolumn, s);
if ~all(col_fields)
    error('Can only text dump column fields');
end
% Identify the types of all fields in order to figure out their formatting
% strings later.
str_fields = structfun(@iscellstr, s);
int_fields = structfun(@isinteger, s);
bool_fields = structfun(@islogical, s);
double_fields = structfun(@(x)isa(x,'double'), s);
single_fields = structfun(@(x)isa(x,'single'), s);
float_fields = double_fields | single_fields;
int_fields = int_fields | bool_fields;
if ~all(str_fields|int_fields|float_fields)
    error('Can only text dump string, numeric, and logical fields');
end
c = structab2cell(s);

% Escape the delimiters and quotes before sending them through formatting:
escape_formats = @(s)regexprep(s,'[%\\]','$0$0');
fieldQuote = escape_formats(opts.FieldQuote);
fieldDelim = escape_formats(opts.FieldDelim);
rowDelim = escape_formats(opts.RowDelim);

% Produce a format string by constructing a cell array like this:
% { fieldQuote,   fieldQuote,   ... fieldQuote   ;
%   fieldFormat1, fieldFormat2, ... fieldFormatN ;
%   fieldQuote,   fieldQuote,   ... fieldQuote   ;
%   fieldDelim,   fieldDelim,   ... rowDelim     }
% and then horizontally concatenating all elements.
formats = cell(4, numel(f));
formats([1 3],:) = {fieldQuote};
formats(4,1:end-1) = {fieldDelim};
formats(4,end) = {rowDelim};
formats(2,str_fields) = {'%s'};
formats(2,int_fields) = {'%d'};
% We need up to 17 digits to specify doubles with full precision, and up to
% 9 digits to specify singles with full precision.
formats(2,double_fields) = {'%.17g'};
formats(2,single_fields) = {'%.9g'};
row_format = [opts.LinePrefix, formats{:}];

if opts.EscapeDelims
    % We will need to perform a regexprep to find any occurrences of the
    % field delimiter, row delimiter, quote character, or a backslash in
    % all of the string fields, and escape them.
    re_parts = {opts.FieldDelim, opts.RowDelim, opts.FieldQuote, '\'};
    re_parts = regexptranslate('escape', re_parts);
    % This is a silly trick to put a | between the fields, but only if
    % they're not empty so we don't get a || in the regular expression:
    re_parts = re_parts(~cellfun(@isempty,re_parts));
    re_parts(2,1:end-1) = {'|'};
    re_parts(2,end) = {''};
    re_match = [re_parts{:}];
    % Escape the offending sequences with a backslash:
    c(:,str_fields) = regexprep(c(:,str_fields), re_match, '\\$0');
end

% Transpose c to iterate through the fields first:
c = c';
if isempty(file)
    % No output file specified: return the result as a string.
    output = sprintf(row_format, c{:});
elseif isnumeric(file)
    % File ID specified: output to an already open file
    fprintf(file, row_format, c{:});
elseif ischar(file)
    % A file name is specified: append to the specified file
    fid = fopen(file, 'a');
    try
        fprintf(fid, row_format, c{:});
    catch e
        fclose(fid);
        rethrow(e);
    end
    fclose(fid);
end