local refFor(node) =
  { _node: node._node } +
  (if std.objectHas(node, '_path') then { _path: node._path } else {}) +
  (if std.objectHasAll(node, '_urlPath') then { _urlPath:: node._urlPath } else {}) +
  (if std.objectHas(node, '_summary') then { _summary: node._summary } else {});

local truncateNodeRec(value, isRoot) =
  if std.isObject(value) then
    if !isRoot && std.objectHas(value, '_node') then
      refFor(value)
    else
      {
        [k]: truncateNodeRec(value[k], false)
        for k in std.objectFields(value)
        if !std.isFunction(value[k])
      }
  else if std.isArray(value) then
    [
      truncateNodeRec(v, false)
      for v in value
      if !std.isFunction(v)
    ]
  else
    value;

function(node) truncateNodeRec(node, true)
