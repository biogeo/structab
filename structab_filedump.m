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
%   structab_filedump(...,'Parameter',value)
%     Specify optional parameters:
%       ReplaceNaNs: A string to replace NaNs. Default '\N'.
%       FieldDelim: The string to insert between fields. Default is tab
%           (sprintf('\t')).
%       RowDelim: The string to insert between rows. Default is newline
%           (sprintf('\n'); not to be confused with the '\N' above).
% 
% At the moment, ONLY these field types are properly handled:
%   strings: The struct's field must be a cell array of strings. The
%     strings will be formatted with a '%s' field in the call to fprintf.
%   numeric scalars: The struct's field must be an N-by-1 numeric array.
%     The field will be formatted with '%-g' in a call to num2str, and the
%     resulting strings will be formatted with '%s' in the call to fprintf.
%     NaNs will be replaced by the ReplaceNaNs parameter.
% Any other types will fail.

p = inputParser;
p.addParamValue('ReplaceNaNs', '\N');
p.addParamValue('FieldDelim', sprintf('\t'));
p.addParamValue('RowDelim', sprintf('\n'));
p.parse(varargin{:});
replaceNaNs = {p.Results.ReplaceNaNs};
fieldDelim = p.Results.FieldDelim;
rowDelim = p.Results.RowDelim;

fields = fieldnames(s);
nfields = numel(fields);
nrows = size(s.(fields{1}),1);

c = cell(nfields, nrows);
for i=1:nfields
    thisF = s.(fields{i});
    if iscellstr(thisF)
        c(i,:) = thisF';
    elseif isnumeric(thisF) && isvector(thisF) && size(thisF,2)==1
        c(i,:) = cellstr(num2str(thisF,'%-g'))';
        c(i,isnan(thisF)) = replaceNaNs;
    else
        error('Unrecognized field type.');
    end
end
fieldAndDelim = ['%s' fieldDelim];
lastFieldStr = ['%s' rowDelim];
formatStr = [repmat(fieldAndDelim,[1 nfields-1]), lastFieldStr];

if ~exist('file','var') || isempty(file)
    file = tempname;
end
if ischar(file)
    opened_file = true;
    fid = fopen(file, 'wt');
elseif isnumeric(file) && isscalar(file)
    opened_file = false;
    fid = file;
else
    error('Bad file name or identifier.');
end

try
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

if nargout
    output = file;
end