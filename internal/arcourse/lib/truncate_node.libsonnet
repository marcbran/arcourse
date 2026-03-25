local joinPath(parts) = std.join('.', parts);

local refFor(node, path) =
  {
    _node: node._node,
    _path: if std.objectHas(node, '_path') then node._path else joinPath(path),
  } +
  if std.objectHas(node, '_summary') then { _summary: node._summary } else {};

local truncateNodeRec(value, path, isRoot) =
  if std.isObject(value) then
    if !isRoot && std.objectHas(value, '_node') then
      refFor(value, path)
    else
      {
        [k]: truncateNodeRec(value[k], path + [k], false)
        for k in std.objectFields(value)
        if !std.isFunction(value[k])
      }
  else if std.isArray(value) then
    [
      truncateNodeRec(v, path + [std.toString(i)], false)
      for i in std.range(0, std.length(value) - 1)
      for v in [value[i]]
      if !std.isFunction(v)
    ]
  else
    value;

function(node) truncateNodeRec(node, [], true)
