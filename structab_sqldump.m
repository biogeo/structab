function cur = structab_sqldump(s, sqldb, table, varargin)
% Load a bulk dataset into an SQL database
% Usage:
%   cur = structab_sqldump(s, sqldb, table)
%     Load the data s into an SQL table. sqldb is a connection to a SQL
%     database using the Database Toolbox function "database", and table
%     names the table to add to. Operates in two steps:
%       1. Create a temporary text file containing the data in s with
%          tab-delimited columns.
%       2. Execute the SQL command:
%            LOAD DATA [LOCAL] INFILE '<tmpfile>'
%                INTO TABLE <table>
%                (<field1>, <field2>, ...);
%          where <tmpfile> is the temporary file name, <table> is the
%          supplied table name, and <field*> are the field names of s. The
%          keyword LOCAL is supplied if the parameter UseLocal is true
%          (default; see below).
%     Note that the field names of s must match the column names of the
%     destination table.
%   cur = structab_sqldump(..., 'Parameter', value, ...)
%     Specify the values of optional parameters. Valid options are:
%       UseLocal: Specifies the usage of the LOCAL keyword in the LOAD DATA
%           command (as above). LOCAL specifies that the infile is local to
%           the SQL client machine, rather than on the server, but if the
%           server is running on localhost these are identical. Default is
%           true.
%       FieldFormats: Specifies format strings for use with
%           structab_filedump: see the documentation on the formats
%           argument for more info. For SQL to read the fields properly,
%           these shouldn't be too fancy, but in particular setting the
%           precision option may be important for ensuring data is not lost
%           in the transfer. E.g., if the SQL table represents a field as
%           DECIMAL(M,2), a format string of '%.2f' would be appropriate.
%           Or, if the field is floating point and you want to avoid loss
%           of precision during the transfer to SQL, be sure to include
%           enough digits in the output to represent the data up to the
%           precision permitted by the type, e.g., '%.16e'. (About 16
%           digits seems to be enough for doubles? But I haven't actually
%           researched this so don't take my word for it.)
%       NansAreNull: Whether NaN values should be interpreted as NULLs by
%           SQL. See structab_filedump for more info.
%       NullString: A value in string fields that should be interpreted as
%           NULLs by SQL, or logical false if there is no such value. E.g.,
%           'null'. Default false.
%
% Of course, if you don't have the Database Toolbox, you can create
% the infiles using structab_filedump and then either load them manually
% from your SQL client, or invoke the SQL client from Matlab via a system
% call.

p = inputParser;
p.addParamValue('UseLocal', true);
p.addParamValue('FieldFormats', []);
p.addParamValue('NansAreNull', true);
p.addParamValue('NullString', false);
p.parse(varargin{:});
opts = p.Results;
passOpts = rmfield(opts, {'UseLocal','FieldFormats'});

if opts.UseLocal
    local_str = 'LOCAL';
else
    local_str = '';
end

fields = fieldnames(s);
names_list = cell(2,numel(fields));
names_list(1,:) = fields(:)';
names_list(2,1:end-1) = {', '};
names_list(2,end) = {''};
names_list = [names_list{:}];
% names_list = sprintf('%s, ', fields{1:end-1});
% names_list = sprintf('(%s%s)', names_list, fields{end});

tmp = structab_filedump(s, [], opts.FieldFormats, passOpts);

try
    cmd = sprintf('LOAD DATA %s INFILE ''%s'' INTO TABLE %s (%s);', ...
        local_str, tmp, table, names_list);
    cur = exec(sqldb, cmd);
catch e
    delete(tmp);
    rethrow(e);
end
delete(tmp);
