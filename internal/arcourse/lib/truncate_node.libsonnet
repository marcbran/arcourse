local refFor(node, mode) =
  { _node: node._node } +
  (if mode == 'eval' && std.objectHasAll(node, '_evalPath') then { _evalPath: node._evalPath } else {}) +
  (if mode == 'query' && std.objectHasAll(node, '_queryPath') then { _queryPath: node._queryPath } else {}) +
  (if std.objectHasAll(node, '_params') then { _params:: node._params } else {}) +
  (if std.objectHas(node, '_summary') then { _summary: node._summary } else {});

local truncateNodeRec(value, isRoot, mode) =
  if std.isObject(value) then
    if !isRoot && std.objectHas(value, '_node') then
      refFor(value, mode)
    else
      {
        [k]: truncateNodeRec(value[k], false, mode)
        for k in std.objectFields(value)
        if !std.isFunction(value[k])
      }
  else if std.isArray(value) then
    [
      truncateNodeRec(v, false, mode)
      for v in value
      if !std.isFunction(v)
    ]
  else
    value;

function(node, mode) truncateNodeRec(node, true, mode)
