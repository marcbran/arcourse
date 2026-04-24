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

local buildNested(path, idx, leaf) =
  if idx == std.length(path) then leaf
  else { [path[idx]]+: buildNested(path, idx + 1, leaf) };

local functionize(obj, vars, defaultView={}, applyDefaultView=true) =
  if !std.isObject(obj) then obj
  else if std.objectHas(obj, '_node') then
    local bound = obj + vars;
    local visibleFields = std.objectFields(obj);
    local hiddenFields = std.setDiff(std.objectFieldsAll(obj), visibleFields);
    local varFields = if std.objectHasAll(obj, '_vars') then obj._vars else [];
    local hiddenDynamicFields = std.foldl(
      function(acc, k) acc + { [k]:: bound[k] },
      std.filter(isVar, visibleFields),
      {}
    );
    local hiddenBase = std.foldl(
      function(acc, k) acc + { [k]:: bound[k] },
      std.filter(function(k) !isVar(k), hiddenFields),
      {}
    );
    local staticResult = {
      [k]+: functionize(bound[k], vars, defaultView, false)
      for k in std.filter(
        function(k)
          !isVar(k) &&
          !std.member(varFields, k) &&
          std.substr(k, 0, 1) != '_' &&
          std.isObject(bound[k]),
        visibleFields
      )
    };
    local dynamicResult = {
      [varNameOf(k)]: function(val) functionize(obj[k], vars + { [varNameOf(k)]: val }, defaultView, false)
      for k in std.filter(isVar, visibleFields)
    };
    local result = staticResult + dynamicResult;
    bound +
    (if std.objectHasAll(obj, '_view') then {} else defaultView) +
    result +
    hiddenDynamicFields +
    hiddenBase
  else
    local fields = std.objectFields(obj);
    local staticResult = {
      [k]+: functionize(obj[k], vars, defaultView, applyDefaultView)
      for k in std.filter(function(k) !isVar(k), fields)
    };
    local dynamicResult = {
      [varNameOf(k)]: function(val) functionize(obj[k], vars + { [varNameOf(k)]: val }, defaultView, applyDefaultView)
      for k in std.filter(isVar, fields)
    };
    local result = staticResult + dynamicResult;
    if applyDefaultView then result + defaultView else result;

local graph(nodes, defaultView={}) =
  local merged = std.foldl(
    function(acc, n) acc + buildNested(n._pathTemplate, 0, n),
    nodes,
    {}
  );
  node([], {}) + functionize(merged, {}, defaultView);

function(graphSpec)
  local nodeSpecs = graphSpec[0];
  local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
  local nodes = std.map(
    function(spec)
      local path = spec[0];
      local body = spec[1];
      local mixins = if std.length(spec) > 2 then spec[2] else [];
      node(path, body, mixins),
    nodeSpecs
  );
  graph(nodes, defaultView)
