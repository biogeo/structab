function c = num2cellstr(n, fmt, rewriteNaN, nanAlign)
% Convert a numeric array to a cell array of strings
% Usage:
%   c = num2cellstr(n)
%     Converts the values in the numeric array n into strings, returning a
%     cell array of the same size as n.
%   c = num2cellstr(n, fmt)
%     Converts the numbers to strings using the formatting string fmt, of
%     the type suitable for use with the *printf functions. The formatting
%     string may be as complex as desired as long as it contains exactly
%     one formatted field. E.g., 'My value is (%010.3f)'.
%   c = num2cellstr(n, fmt, rewriteNaN)
%     Causes NaN values to be printed as the string in rewriteNaN instead
%     of 'NaN'.
%   c = num2cellstr(n, fmt, rewriteNaN, nanAlign)
%     Optionally allows the rewritten NaN string to be aligned differently
%     than other values. If nanAlign is negative, the rewriteNaN value will
%     be aligned left; if positive, it will be aligned right; and if zero,
%     it will follow the alignment specified in fmt (the same as if not
%     supplied).

if ~exist('fmt','var') || isempty(fmt)
    fmt = '%g';
end
% Format the numeric into a character matrix (ugh), enclosed in :'s
c = num2str(n(:), [':' fmt ':']);
% Convert to cell array of strings. Desired whitespace is safe inside the
% :'s.
c = cellstr(c);
% Extract everything between the :'s using a regular expression. Read this
% as "match all characters which are preceded by (the start of the string,
% followed by zero or more spaces, followed by a ':') and followed by (a
% ':', followed by the end of the string)"
c = regexp(c, '(?<=^ *:).*(?=:$)', 'match', 'once');
% Restore original dimensions
c = reshape(c, size(n));

if exist('rewriteNaN','var')
    % NaN values need to be replaced by the supplied string.
    
    fmt_expr = '%[+ 0#]*(-?)[+ 0#]*(\d*)\.?\d*[btlh]?[cdeEfgGosuxX]';
    % The above regular expression matches formatting fields and captures
    % two tokens:
    %   1. The '-' flag if it is supplied
    %   2. The field width if it is supplied
    
    if exist('nanAlign','var') && nanAlign ~= 0
        % Override the '-' flag based on the sign of nanAlign
        if nanAlign < 0
            replace_expr = '%-$2s';
        else
            replace_expr = '%$2s';
        end
    else
        % Use the '-' flag from the original format expression
        replace_expr = '%$1$2s';
    end
    
    fmt_nan = regexprep(fmt, fmt_expr, replace_expr);
    nan_str = sprintf(fmt_nan, rewriteNaN);
    
    c(isnan(n)) = {nan_str};
end