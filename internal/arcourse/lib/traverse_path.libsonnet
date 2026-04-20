local traverseRec(obj, path) =
  if std.length(path) == 0 then obj
  else
    local field = obj[path[0]];
    if std.isFunction(field) then
      traverseRec(field(path[1]), path[2:])
    else
      traverseRec(field, path[1:]);

function(obj, path) traverseRec(obj, path)
