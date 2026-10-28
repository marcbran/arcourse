local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varNameOf(seg) = std.substr(seg, 1, std.length(seg) - 1);
local quote(s) = std.escapeStringJson(s);

local flatten(shapeNode, path) =
  [{ shapeNode: shapeNode, path: path }] + std.flatMap(
    function(k) flatten(shapeNode.children[k], path + [k]),
    std.objectFields(shapeNode.children)
  );

function(graphSpecExpr, shape)
  local nodes = flatten(shape, []);
  local ids = { [std.manifestJsonMinified(nodes[i].path)]: i for i in std.range(0, std.length(nodes) - 1) };
  local fnName(path) = 'n' + ids[std.manifestJsonMinified(path)];
  local fnRef(path) = 'levels.' + fnName(path);
  local childField(path, k) =
    if isVar(k) then
      local name = quote(varNameOf(k));
      '    ' + name + ': function(val) ' + fnRef(path + [k]) + '(vars { ' + name + ': val }),\n'
    else
      '    ' + quote(k) + ': ' + fnRef(path + [k]) + '(vars),\n';
  local fnDef(node) =
    local shapeNode = node.shapeNode;
    local fields = std.objectFields(shapeNode.children);
    local children =
      if std.length(fields) == 0 then '{}'
      else '{\n' + std.join('', [childField(node.path, k) for k in fields]) + '  }';
    local leafs = shapeNode.leafs;
    local body =
      if std.length(leafs) == 0 then children
      else
        'g.node(layers[' + leafs[0] + '].fullPath, ['
        + std.join(', ', ['layers[' + i + '].layer' for i in leafs])
        + ']) + vars' + (if std.length(fields) == 0 then '' else ' + ' + children);
    '  ' + fnName(node.path) + '(vars):: view(' + body + '),\n';
  "local g = import 'lib/arcourse-graph/main.libsonnet';\n"
  + 'local graphSpec = ' + graphSpecExpr + ';\n'
  + 'local layers = g.toLayers(graphSpec[0]);\n'
  + 'local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};\n'
  + "local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;\n"
  + 'local levels = {\n'
  + std.join('', [fnDef(node) for node in nodes])
  + '};\n'
  + 'view(g.node([]) + levels.n0({}))\n'
