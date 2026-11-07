local notFound(walked) = {
  _failure: { code: 404, reason: 'Not Found', message: 'no node at %s' % std.join('/', ['root'] + walked) },
};

local traverseRec(obj, path, walked) =
  if std.length(path) == 0 then obj
  else if !std.isObject(obj) || !std.objectHasAll(obj, path[0]) then notFound(walked + [path[0]])
  else
    local field = obj[path[0]];
    if std.isFunction(field) then
      if std.length(path) < 2 then notFound(walked + [path[0]])
      else traverseRec(field(path[1]), path[2:], walked + path[0:2])
    else
      traverseRec(field, path[1:], walked + [path[0]]);

function(obj, path) traverseRec(obj, path, [])
