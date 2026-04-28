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
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  local build(specs, vars={}) =
    local leafs = [s for s in specs if std.length(s.path) == 0];
    local children = {
      [if isVar(k) then varNameOf(k) else k]:
        local childSpecs = [
          s { path: std.slice(s.path, 1, null, 1) }
          for s in specs
          if std.length(s.path) > 0 && s.path[0] == k
        ];
        if isVar(k) then
          local vName = varNameOf(k);
          function(val) build(childSpecs, vars + { [vName]: val })
        else
          build(childSpecs, vars)
      for k in firstSegments(specs)
    };
    if std.length(leafs) == 0 then withDefaultView(children)
    else if std.length(leafs) == 1 then withDefaultView(node(leafs[0].fullPath, leafs[0].body, leafs[0].mixins) + vars + children)
    else error 'duplicate node path: %s' % std.manifestJson(leafs[0].fullPath);
  withDefaultView(node([], {}) + build(specs));

{
  node: node,
  graph: graph,
}
