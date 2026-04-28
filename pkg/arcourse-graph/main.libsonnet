local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varNameOf(seg) = std.substr(seg, 1, std.length(seg) - 1);

local resolvePath(node, path) =
  std.join('.', ['root'] + [
    if isVar(p) then varNameOf(p) + '("' + node[varNameOf(p)] + '")'
    else p
    for p in path
  ]);

local resolveUrlPath(node, path) =
  std.join('/', ['/root'] + std.flatMap(
    function(p)
      if isVar(p) then [varNameOf(p), node[varNameOf(p)]]
      else [p],
    path
  ));

local node(path, res, mixins=[]) =
  local mixinsArray = if std.isArray(mixins) then mixins else [mixins];
  local vars = std.map(varNameOf, std.filter(isVar, path));
  { [var]: error 'variable %s is required' % var for var in vars } +
  {
    _node: true,
    _vars:: vars,
    _pathTemplate:: path,
    _path: resolvePath(self, path),
    _urlPath:: resolveUrlPath(self, path),
  } +
  res +
  std.foldl(function(acc, m) acc + m, mixinsArray, {});

local isNode(obj) = std.isObject(obj) && std.objectHas(obj, '_node');

local deepMerge(a, b) =
  if std.isObject(a) && std.isObject(b) && !isNode(a) && !isNode(b) then
    local keys = std.setUnion(std.objectFields(a), std.objectFields(b), function(k) k);
    {
      [k]:
        if std.objectHas(a, k) && std.objectHas(b, k) then deepMerge(a[k], b[k])
        else if std.objectHas(b, k) then b[k]
        else a[k]
      for k in keys
    }
  else b;

local functionize(obj, vars, defaultView={}) =
  if !std.isObject(obj) then obj
  else if isNode(obj) then
    if std.objectHasAll(obj, '_view') then obj + vars
    else obj + vars + defaultView
  else
    local fields = std.objectFields(obj);
    local staticResult = {
      [k]: functionize(obj[k], vars, defaultView)
      for k in std.filter(function(k) !isVar(k), fields)
    };
    local result = std.foldl(
      function(acc, k)
        local vName = varNameOf(k);
        acc + { [vName]: function(val) functionize(obj[k], vars + { [vName]: val }, defaultView) },
      std.filter(isVar, fields),
      staticResult
    );
    result + defaultView;

local merge(fragments, defaultView={}) =
  local merged = std.foldl(deepMerge, fragments, {});
  node([], {}) + functionize(merged, {}, defaultView);

local graph(nodeSpecs, defaultView={}) =
  local specs = [
    {
      path: spec[0],
      fullPath: spec[0],
      body: spec[1],
      mixins: if std.length(spec) > 2 then spec[2] else [],
    }
    for spec in nodeSpecs
  ];
  local firstSegments(specs) =
    std.set([s.path[0] for s in specs if std.length(s.path) > 0], function(k) k);
  local build(specs) =
    local leafs = [s for s in specs if std.length(s.path) == 0];
    local children = {
      [k]: build([
        s { path: std.slice(s.path, 1, null, 1) }
        for s in specs
        if std.length(s.path) > 0 && s.path[0] == k
      ])
      for k in firstSegments(specs)
    };
    if std.length(leafs) == 0 then children
    else if std.length(leafs) == 1 then node(leafs[0].fullPath, leafs[0].body, leafs[0].mixins) + children
    else error 'duplicate node path: %s' % std.manifestJson(leafs[0].fullPath);
  merge([build(specs)], defaultView);

{
  node: node,
  graph: graph,
  merge: merge,
}
