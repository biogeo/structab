% ## structab
% Several simple functions for treating structs as tables.
% 
% Sometimes it's useful to have a `struct` serve as a table, where each field
% represents a column. This mostly works fine as-is, but occasionally it's
% nice to do slightly more complicated things, like concatenate the data
% from two tables, or query or index a subset of the rows in the table. One
% could create a Matlab class for tables with methods for these things.
% That's a perfectly good solution, but a bit of a bother. Here's a few
% simple functions to accomplish some basic tasks, plus a really easy way
% to dump a large amount of data into an SQL table using the Database
% Toolbox.
% 
% These functions consider a table to be:
% 
% 1. A scalar `struct`
% 2. where each field is the same size in dimension 1 (rows)
% 3. such that the corresponding row entry in each field, taken together,
%    make the "row" of a table.
% 
% Note that if you use the Database Toolbox, the results of SQL queries are
% returned in this format when the option `DataReturnFormat` is `'structure'`.
% 
% These functions let you:
% * Swap which dimension is the "row" dimension (e.g., you may have code which
%   operates on row vectors rather than column vectors): `structab_swapdim`
% * Convert tables to and from cell arrays where each cell represents an
%   item in a row: `structab2cell`, `cell2structab`
% * Convert tables to and from `struct` arrays where each element represents
%   a "row": `structab2arr`, `structarr2tab`
% * Concatenate several tables into one containing all their rows: `structab_cat`
% * Retrieve subsets of the table by index or condition: `structab_index`,
%   `structab_lookup`
% * For common types of tables (fields are either strings or numeric
%   scalars), quickly and easily dump to text files: `structab_textdump`
% * For these types of tables, dump to an SQL table via the Database
%   Toolbox and a call to `LOAD DATA INFILE` -- for large amounts of data,
%   this is *much* (up to three orders of magnitude in a test I did) faster
%   than using calls to `INSERT` (or, therefore, the Database Toolbox `datainsert`
%   function): `structab_sqldump`
% 
% Basically, this is just a quick-and-dirty solution. For something more elegant,
% write a class.

help structab;
