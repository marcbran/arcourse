local hexDigits = '0123456789ABCDEF';

local unreserved(b) =
  (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57)
  || b == 45 || b == 95 || b == 46 || b == 126;

local percentEncode(s) =
  std.join('', [
    if unreserved(b) then std.char(b)
    else '%' + hexDigits[std.floor(b / 16)] + hexDigits[b % 16]
    for b in std.encodeUTF8(s)
  ]);

local queryValue(value) =
  if std.isString(value) then value
  else if std.isArray(value) then std.manifestJsonMinified(value)
  else std.toString(value);

local query(params) =
  local keys = std.objectFields(params);
  if std.length(keys) == 0 then ''
  else '?' + std.join('&', [
    percentEncode(k) + '=' + percentEncode(queryValue(params[k]))
    for k in keys
  ]);

function(u)
  local scheme = std.get(u, 'scheme', null);
  local path = std.get(u, 'path', []);
  (if scheme != null then scheme + '://' else '')
  + std.get(u, 'host', '')
  + (if std.length(path) > 0 then '/' + std.join('/', [percentEncode(seg) for seg in path]) else '')
  + query(std.get(u, 'params', {}))
