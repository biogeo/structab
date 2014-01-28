function cur = structab_sqldump(s, sqldb, table, varargin)
% Load a bulk dataset into an SQL database
% Usage:
%   cur = structab_sqldump(s, sqldb, table)
%     Load the data s into an SQL table. sqldb is a connection to a SQL
%     database using the Database Toolbox function "database", and table
%     names the table to add to. Operates in two steps:
%       1. Create a temporary text file containing the data in s with
%          tab-delimited columns.
%       2. Executes a LOAD DATA INFILE query to load the data into the
%          specified table.
%     Returns a cursor object resulting from the query.
%     A side effect is that SQL user-defined variables @structabv1,
%     @structabv2, etc. may be created or modified.
%   cur = structab_sqldump(..., 'Parameter', value, ...)
%     Specify optional parameters to customize the behavior. Valid
%     parameters are (* denotes default value):
%         NullNaNs: [true* | false]
%             SQL does not support floating point NaN values, and by
%             default MySQL will replace them with zeros. If true, this
%             option will cause MySQL to treat them as NULL. If the table
%             contains no NaN values, setting to false might yield a speed
%             improvement.
%         NullInfs: [true* | false]
%             SQL also does not support Inf (or -Inf), and will replace
%             them with zeros too. If true, MySQL will treat them as NULL.
%         NullString: [false* | <string>]
%             If false, all strings are imported exactly as-is. If set to a
%             string, any strings that match will be replaced with NULL.
%         ReplaceOrIgnore: ['REPLACE' | 'IGNORE' | ''*]
%             Permits the REPLACE or IGNORE keywords for dealing with
%             duplicate data. If the loaded data contains rows that
%             duplicate existing unique or primary keys, this is normally
%             an error. If REPLACE is specified, the existing row is
%             replaced with the new data; if IGNORE is specified, the
%             original row is preserved and the new data discarded. The
%             empty string ('') means neither is specified.
% 
%     The following parameters are more advanced but allow more fine-
%     tuning of the query.
%         UseLocal: [true* | false]
%             Whether to include the LOCAL keyword as part of the LOAD DATA
%             query. This specifies that the data file is on the SQL client
%             machine rather than the server, but if running the server on
%             localhost these are of course the same and LOCAL can be
%             omitted.
%         EscapeDelims: [true* | false]
%             String fields could contain characters (specifically, tabs,
%             newlines, and backslashes)  which would prevent SQL from
%             parsing the file properly. This option will cause these
%             characters to be escaped with backslashes. If the data are
%             known not to contain these characters, setting EscapeDelims
%             to false may give some speed improvement.
%         ConstFields: [{}* | <struct> | <2xN cell array>]
%             Allows additional "constant" fields (that is, the same value
%             is in every row) to be supplied. In effect, this is the same
%             as adding an additional field to the table with repmat
%             copying a single value to every row, but this should be MUCH
%             more efficient. The constant fields can be supplied either as
%             a struct, the field names of which give the SQL field names,
%             and the values of which give the constant value, or as a
%             2-by-N cell array, where the first row gives the field names
%             and the second row gives the values. E.g., to supply fields
%             foo and bar with values 'spam' and 12, respectively, either
%             give the struct:
%                 foo: 'spam'
%                 bar: 12
%             or the cell array:
%                 {'foo',  'bar';
%                  'spam', 12   }
%             Values must be strings (1xM character arrays) or numeric or
%             logical scalars. The NullNaNs, NullInfs, and NullString rules
%             will be applied. Integer or logical class values will be
%             formatted with %d, doubles with %.17g, and singles with %.9g.
%         SQLFields: [{} | <struct> | <2xN cell array>]
%             Allows additional fields to be specified with SQL subquery.
%             NOTE: THERE IS NO ATTEMPT TO PROTECT THIS FROM AN SQL
%             INJECTION ATTACK. THIS CODE IS INTENDED FOR SAFE ENVIRONMENTS
%             WITH NO EXPOSED ATTACK SURFACE. IF THIS CODE SOMEHOW ENDS UP
%             RUNNING IN A CONTEXT WHERE A MALICIOUS USER COULD USE THIS TO
%             ATTACK YOUR DATABASE IN A WAY THAT WASN'T ALREADY POSSIBLE BY
%             USING THE DATABASE TOOLBOX, SOMETHING HAS GONE TERRIBLY
%             WRONG. This should be safe if you're just connecting to a
%             local database and running only your own Matlab code, but I
%             make no guarantees!
%             These extra fields are given with a struct or a 2-by-N cell
%             array, as with ConstFields, but the value is a string
%             containing an SQL subquery. E.g., suppose you have a
%             pre-existing table "subjects" with columns "name" and "id",
%             and you are loading a large amount of data into different
%             table pertaining to a particular subject, for which you have
%             the name but not the id. Then you might supply:
%                 {'subject';
%                  '(SELECT id FROM subjects WHERE name = "David Bowie")'}
%             This would cause all rows to have the field "subject" take
%             David Bowie's subject id. (The same effect could be achieved
%             using a ConstField and subsequently JOINing the tables, but
%             this could have performance advantages under certain
%             conditions.)
%         Verbose: [true | false*]
%             If true, displays the SQL query used. This can also be
%             retrieved from the returned cursor object, of course. For
%             debugging purposes mostly.
%         TempVarBase: ['structabv'* | <string>]
%             If NullNaNs, NullInfs, or NullString are set, some
%             user-defined variables are required on the SQL side to
%             process the file. By default these will be named @structabv1,
%             @structabv2, etc. If by some weird circumstance this
%             conflicts with other code, the names of these temporary
%             variables can be changed. E.g., if 'foo' is supplied, they
%             will be @foo1, @foo2, etc.
%
% The exact SQL query used depends on the supplied data and the options
% set. It will take the form:
%   LOAD DATA [LOCAL] INFILE "<temp file path>"
%     [REPLACE|IGNORE] INTO TABLE <table name>
%     (<inp1>, <inp2>, ...)
%     [SET <exp1>, <exp2>, ...];
% where <inpN> is either the name of the Nth field (if the values will be
% read raw) or a user-defined variable @<varN>. The user-defined variable
% is used if the raw values will need to be processed, which will occur if
% the field is float and NullNaNs or NullInfs is set, or if the field is
% string and NullString is set. In these cases, <expN> will also be
% provided:
%   <expN> if string and NullString:
%       <colN> = NULLIF(@<varN>, <null string>)
%   <expN> if single/double and NullNaNs and NullInfs:
%       <colN> = CASE WHEN FIND_IN_SET(@<varN>, "NaN,Inf,-Inf")
%                    THEN NULL
%                    ELSE @<varN> END
%     (If NullNaNs is not set but NullInfs is, only "Inf,-Inf" is used, and
%     if vice versa, only "NaN" is used.)
%
% Additionally, if ConstFields are supplied, then additional SET
% expressions are also given, simply as:
%   <constCol> = <value>
% where <value> is properly formatted as a string. And if SQLFields are
% supplied, then additional SET expressions are:
%   <sqlCol> = <expr>
% where <expr> is the raw supplied SQL expression.

p = inputParser;
p.addParamValue('UseLocal', true);
p.addParamValue('ReplaceOrIgnore', '', ...
    @(x)ismember(upper(x),{'REPLACE','IGNORE',''}));
p.addParamValue('NullNaNs', true);
p.addParamValue('NullInfs', true);
p.addParamValue('NullString', false);
p.addParamValue('ConstFields', {});
p.addParamValue('SQLFields', {});
p.addParamValue('EscapeDelims', true);
p.addParamValue('TempVarBase', 'structabv');
p.addParamValue('Verbose', false);
p.parse(varargin{:});
opts = p.Results;

if opts.UseLocal
    localStr = 'LOCAL';
else
    localStr = '';
end

fields = fieldnames(s)';
str_fields = structfun(@iscellstr, s);
float_fields = structfun(@isfloat, s);

fieldArgs = fields;
varNames = strcat('@', opts.TempVarBase, num2cellstr(1:numel(fields)));
setArgs = repmat({''}, size(fields));

if ischar(opts.NullString)
    for i=1:numel(fields)
        if str_fields(i)
            fieldArgs(i) = varNames(i);
            setArgs{i} = sprintf('%s = NULLIF(%s, "%s")', ...
                fields{i}, varNames{i}, opts.NullString);
        end
    end
end

if opts.NullNaNs || opts.NullInfs
    if opts.NullNaNs && opts.NullInfs
        nullStrs = 'NaN,Inf,-Inf';
    elseif opts.NullNaNs
        nullStrs = 'NaN';
    elseif opts.NullInfs
        nullStrs = 'Inf,-Inf';
    end
    for i=1:numel(fields)
        if float_fields(i)
            fieldArgs(i) = varNames(i);
            setArgs{i} = sprintf(...
                ['%s = CASE WHEN FIND_IN_SET(%s, "%s") ' ...
                'THEN NULL ELSE %s END'], ...
                fields{i}, varNames{i}, nullStrs, varNames{i});
        end
    end
end

constFields = opts.ConstFields;
if isstruct(constFields)
    constFields = [
        fieldnames(constFields)';
        struct2cell(constFields)' ];
end
constArgs = cell(1,size(constFields,2));
for i=1:numel(constArgs)
    constVal = constFields{2,i};
    if ischar(constVal)
        if ischar(opts.NullString) && strcmp(constVal, opts.NullString)
            constVal = 'NULL';
        else
            constVal = regexprep(constVal, '["\\]', '\\$0');
            constVal = sprintf('"%s"', constVal);
        end
    elseif (isinteger(constVal) || islogical(constVal)) ...
            && isscalar(constVal)
        constVal = sprintf('%d', constVal);
    elseif isfloat(constVal) && isscalar(constVal)
        if (isnan(constVal) && opts.NullNaNs) ...
                || (isinf(constVal) && opts.NullInfs)
            constVal = 'NULL';
        else
            if isa(constVal, 'double')
                constVal = sprintf('%.17g', constVal);
            else % it's a single
                constVal = sprintf('%.9g', constVal);
            end
        end
    else
        error('Constant fields must be string or numeric scalar.')
    end
    constArgs{i} = sprintf('%s = %s', constFields{1,i}, constVal);
end


sqlFields = opts.SQLFields;
if isstruct(sqlFields)
    sqlFields = [
        fieldnames(sqlFields)';
        struct2cell(sqlFields)' ];
end
sqlArgs = cell(1,size(sqlFields,2));
for i=1:numel(sqlArgs)
    sqlArgs{i} = sprintf('%s = %s', sqlFields{1,i}, sqlFields{2,i});
end


fieldArgs(2,1:end-1) = {', '};
fieldArgs(2,end) = {''};
fieldList = [fieldArgs{:}];

setArgs = setArgs(~cellfun(@isempty, setArgs));
setArgs = [setArgs, constArgs, sqlArgs];
if ~isempty(setArgs)
    setArgs(2,1:end-1) = {', '};
    setArgs(2,end) = {''};
    setCmds = ['SET ', setArgs{:}];
end

file = tempname;
structab_textdump(s, file, 'EscapeDelims', opts.EscapeDelims);

try
    cmd = sprintf('LOAD DATA %s INFILE "%s" %s INTO TABLE %s (%s) %s;', ...
        localStr, file, opts.ReplaceOrIgnore, table, fieldList, setCmds);

    if opts.Verbose
        disp(cmd);
    end

    cur = exec(sqldb, cmd);
catch e
    delete(file);
    rethrow(e);
end

delete(file);
