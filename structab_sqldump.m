function cur = structab_sqldump(s, sqldb, table)
% Load a bulk dataset into an SQL database
% Usage:
%   cur = structab_sqldump(s, sqldb, table)
%     Load the data s into an SQL table. sqldb is a connection to a SQL
%     database using the Database Toolbox function "database", and table
%     names the table to add to. Operates in two steps:
%       1. Create a temporary text file containing the data in s with
%          tab-delimited columns.
%       2. Execute the SQL command:
%            LOAD DATA INFILE '<tmpfile>'
%                INTO TABLE <table>
%                (<field1>, <field2>, ...);
%          where <tmpfile> is the temporary file name, <table> is the
%          supplied table name, and <field*> are the field names of s.
%     Note that the field names of s must match the column names of the
%     destination table.

fields = fieldnames(s);
names_clause = sprintf('%s, ', fields{1:end-1});
names_clause = sprintf('(%s%s)', names_clause, fields{end});

tmp = structab_filedump(s);

try
    cmd = sprintf('LOAD DATA LOCAL INFILE ''%s'' INTO TABLE %s %s;', ...
        tmp, table, names_clause);
    cur = exec(sqldb, cmd);
catch e
    delete(tmp);
    rethrow(e);
end
delete(tmp);
