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
    local childNames = std.set([if isVar(k) then varNameOf(k) else k for k in fields]);
    local conflicts = std.set([varNameOf(seg) for seg in node.path if isVar(seg) && std.setMember(varNameOf(seg), childNames)]);
    local exclude = if std.length(conflicts) == 0 then '' else ', ' + std.manifestJsonMinified(conflicts);
    local leafs = shapeNode.leafs;
    local layerList = '[' + std.join(', ', ['layers[' + i + '].layer' for i in leafs]) + ']';
    local hasVars = std.length(std.filter(isVar, node.path)) > 0;
    local shadowedName = 's' + ids[std.manifestJsonMinified(node.path)];
    local shadowedDef =
      if std.length(leafs) == 0 || !hasVars then ''
      else '  ' + shadowedName + ':: g.shadowedVars(' + std.manifestJsonMinified(node.path) + ', ' + layerList + exclude + '),\n';
    local body =
      if std.length(leafs) == 0 then
        'g.intermediate(' + std.manifestJsonMinified(node.path) + ', vars' + exclude + ') + ' + children
      else
        'g.node(layers[' + leafs[0] + '].fullPath, ' + layerList + ', vars'
        + (if hasVars then ', levels.' + shadowedName else '') + ')'
        + (if std.length(fields) == 0 then '' else ' + ' + children);
    shadowedDef + '  ' + fnName(node.path) + '(vars):: view(' + body + '),\n';
  "local g = import 'lib/arcourse-graph/main.libsonnet';\n"
  + 'local graphSpec = ' + graphSpecExpr + ';\n'
  + 'local layers = g.toLayers(graphSpec[0]);\n'
  + 'local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};\n'
  + "local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;\n"
  + 'local levels = {\n'
  + std.join('', [fnDef(node) for node in nodes])
  + '};\n'
  + 'view(g.node([]) + levels.n0({}))\n'
