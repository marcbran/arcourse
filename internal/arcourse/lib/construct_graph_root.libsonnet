local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varNameOf(seg) = std.substr(seg, 1, std.length(seg) - 1);

local resolvePath(node, path) =
  std.join('.', ['.root'] + [
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

local buildNested(path, idx, leaf) =
  if idx == std.length(path) then leaf
  else { [path[idx]]+: buildNested(path, idx + 1, leaf) };

local functionize(obj, vars, defaultView={}) =
  if !std.isObject(obj) then obj
  else if std.objectHas(obj, '_node') then
    if std.objectHasAll(obj, '_view') then obj + vars
    else obj + vars + defaultView
  else
    local fields = std.objectFields(obj);
    local staticResult = {
      [k]+: functionize(obj[k], vars, defaultView)
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

local graph(nodes, defaultView={}) =
  local merged = std.foldl(
    function(acc, n) acc + buildNested(n._pathTemplate, 0, n),
    nodes,
    {}
  );
  node([], {}) + functionize(merged, {}, defaultView);

function(nodeSpecs)
  local nodes = std.map(
    function(spec)
      local path = spec[0];
      local body = spec[1];
      local mixins = if std.length(spec) > 2 then spec[2] else [];
      node(path, body, mixins),
    nodeSpecs
  );
  graph(nodes, {})
