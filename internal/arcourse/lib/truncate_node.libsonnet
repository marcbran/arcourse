local defaultParams(specs) = {
  [spec.name]: spec.default
  for spec in specs
  if std.objectHas(spec, 'default') && spec.default != null
};

local withDefaultParams(node) =
  if std.objectHasAll(node, '_params') || !std.objectHasAll(node, '_paramSpecs') then node
  else node { _params:: defaultParams(node._paramSpecs) };

local refFor(node, mode) =
  { _node: node._node } +
  (if mode == 'eval' && std.objectHasAll(node, '_evalPath') then { _evalPath: node._evalPath } else {}) +
  (if mode == 'query' && std.objectHasAll(node, '_queryPath') then { _queryPath: node._queryPath } else {}) +
  (if std.objectHasAll(node, '_paramSpecs') then { _paramSpecs: node._paramSpecs } else {}) +
  (if std.objectHas(node, '_summary') then { _summary: withDefaultParams(node)._summary } else {});

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
