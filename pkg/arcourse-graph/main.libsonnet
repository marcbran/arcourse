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

local mergeLayers(layers) =
  std.foldl(function(acc, l) acc + l, layers, {});

local node(path, body={}) =
  local layers = if std.isArray(body) then body else [body];
  local vars = std.map(varNameOf, std.filter(isVar, path));
  { [var]: error 'variable %s is required' % var for var in vars } +
  {
    _node: true,
    _vars:: vars,
    _pathTemplate:: path,
    _evalPath:: resolvePath(self, path),
    _queryPath:: resolveUrlPath(self, path),
  } +
  mergeLayers(layers);

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

local instantiateFromShape(shapeNode, layers, defaultView={}, vars={}) =
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  local leafs = [layers[i] for i in shapeNode.leafs];
  local children = {
    [if isVar(k) then varNameOf(k) else k]:
      if isVar(k) then
        local vName = varNameOf(k);
        function(val) instantiateFromShape(shapeNode.children[k], layers, defaultView, vars + { [vName]: val })
      else
        instantiateFromShape(shapeNode.children[k], layers, defaultView, vars)
    for k in std.objectFields(shapeNode.children)
  };
  if std.length(leafs) == 0 then withDefaultView(children)
  else withDefaultView(node(leafs[0].fullPath, [l.layer for l in leafs]) + vars + children);

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
  graph: graph,
  toLayers: toLayers,
  shape: shape,
  graphFromShape: graphFromShape,
}
