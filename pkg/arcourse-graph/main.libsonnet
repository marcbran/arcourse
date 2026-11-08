local failure = import 'failure.libsonnet';
local url(u) = std.native('invoke:url')('format', [u]);

local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varNameOf(seg) = std.substr(seg, 1, std.length(seg) - 1);

local varValue(node, name) =
  if std.objectHasAll(node, '_vars') && std.objectHas(node._vars, name) then node._vars[name] else node[name];

local resolvePath(node, path) =
  std.join('.', ['root'] + [
    if isVar(p) then varNameOf(p) + '("' + varValue(node, varNameOf(p)) + '")'
    else p
    for p in path
  ]);

local urlPathSegments(node, path) =
  ['root'] + std.flatMap(
    function(p)
      if isVar(p) then [varNameOf(p), varValue(node, varNameOf(p))]
      else [p],
    path
  );

local specDefaults(specs) = {
  [spec.name]: spec.default
  for spec in specs
  if std.objectHas(spec, 'default') && spec.default != null
};

local nonDefaultParams(node) =
  local params = node._params;
  if std.length(params) == 0 then {}
  else
    local defaults = node._defaultParams;
    {
      [k]: params[k]
      for k in std.objectFields(params)
      if !std.objectHas(defaults, k) || defaults[k] != params[k]
    };

local mergeLayers(base, layers) =
  std.foldl(function(acc, l) acc + l, layers, base);

local varFields(vars, shadowed) =
  { [v]: vars[v] for v in std.objectFields(vars) if !std.member(shadowed, v) } + { _vars:: { [v]: vars[v] for v in shadowed } };

local shadowedVars(path, layers, exclude=[]) =
  local merged = mergeLayers({}, layers);
  exclude + [
    v
    for v in std.map(varNameOf, std.filter(isVar, path))
    if !std.member(exclude, v) && std.objectHasAll(merged, v)
  ];

local node(path, body={}, vars={}, shadowed=[]) =
  local layers = if std.isArray(body) then body else [body];
  local pathVars = std.map(varNameOf, std.filter(isVar, path));
  local base = { _params:: specDefaults(std.get(self, '_paramSpecs', [])) };
  local requiredVars = { [var]: error 'variable %s is required' % var for var in pathVars };
  mergeLayers(if std.length(pathVars) == 0 || std.length(vars) > 0 then base else requiredVars + base, layers) +
  {
    _node: true,
    _pathTemplate:: path,
    _defaultParams:: super._params,
    _evalPath:: resolvePath(self, path),
    _queryPath:: local n = self; url({ path: urlPathSegments(n, path), params: nonDefaultParams(n) }),
  } +
  (if std.length(shadowed) == 0 then vars else varFields(vars, shadowed));

local intermediate(path, vars, exclude=[]) =
  std.foldl(
    function(acc, v) if std.member(exclude, v) then acc else acc { [v]:: vars[v] },
    std.objectFields(vars),
    if std.length(exclude) == 0 then { _pathTemplate:: path }
    else { _pathTemplate:: path, _vars:: { [v]: vars[v] for v in exclude } }
  );

local toLayers(nodeSpecs) =
  std.flatMap(
    function(spec)
      local bodies = std.slice(spec, 1, null, 1);
      local effective = if std.length(bodies) == 0 then [{}] else bodies;
      [{ path: spec[0], fullPath: spec[0], layer: b } for b in effective],
    nodeSpecs,
  );

local shape(layers) =
  local build(ls) =
    local firstSegments(ls) =
      std.set([l.path[0] for l in ls if std.length(l.path) > 0], function(k) k);
    {
      leafs: [l.index for l in ls if std.length(l.path) == 0],
      children: {
        [k]: build([
          l { path: std.slice(l.path, 1, null, 1) }
          for l in ls
          if std.length(l.path) > 0 && l.path[0] == k
        ])
        for k in firstSegments(ls)
      },
    };
  build([{ path: layers[i].path, index: i } for i in std.range(0, std.length(layers) - 1)]);

local instantiateFromShape(shapeNode, layers, defaultView={}, vars={}, path=[]) =
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  local leafs = [layers[i] for i in shapeNode.leafs];
  local children = {
    [if isVar(k) then varNameOf(k) else k]:
      if isVar(k) then
        local vName = varNameOf(k);
        function(val) instantiateFromShape(shapeNode.children[k], layers, defaultView, vars { [vName]: val }, path + [k])
      else
        instantiateFromShape(shapeNode.children[k], layers, defaultView, vars, path + [k])
    for k in std.objectFields(shapeNode.children)
  };
  local conflicts = [v for v in std.objectFields(vars) if std.objectHas(children, v)];
  if std.length(leafs) == 0 then withDefaultView(intermediate(path, vars, conflicts) + children)
  else
    local leafLayers = [l.layer for l in leafs];
    withDefaultView(node(leafs[0].fullPath, leafLayers, vars, shadowedVars(path, leafLayers, conflicts)) + children);

local rootFromShape(layers, compiledShape, defaultView={}) =
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  withDefaultView(node([]) + instantiateFromShape(compiledShape, layers, defaultView));

local graphFromShape(nodeSpecs, compiledShape, defaultView={}) =
  rootFromShape(toLayers(nodeSpecs), compiledShape, defaultView);

local graph(nodeSpecs, defaultView={}) =
  local layers = toLayers(nodeSpecs);
  rootFromShape(layers, shape(layers), defaultView);

{
  node: node,
  intermediate: intermediate,
  shadowedVars: shadowedVars,
  graph: graph,
  toLayers: toLayers,
  shape: shape,
  graphFromShape: graphFromShape,
  failure: failure,
}
