local j = import 'jsonnet/main.libsonnet';
local openapi = import 'openapi/main.libsonnet';

local generate(service, spec, manifest=true) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([
      elem.fodder(le(indent + 2))
      for elem in elements
    ]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([
      field { fodder: [le(indent + 2)] }
      for field in fields
    ]).closeFodder(le(indent));
  local prettyApply(target, args, indent=0) =
    j.Apply(target, [
      arg.fodder(le(indent + 2))
      for arg in args
    ]).rightFodder(le(indent));

  local isAsciiLetter(c) =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
  local isAsciiDigit(c) = c >= '0' && c <= '9';
  local isJsonnetIdent(s) =
    if std.length(s) == 0 then false
    else
      local len = std.length(s);
      local identStart(c) = c == '_' || isAsciiLetter(c);
      local identPart(c) = identStart(c) || isAsciiDigit(c);
      local check(i) =
        if i >= len then true
        else if i == 0 then identStart(s[i]) && check(i + 1)
        else identPart(s[i]) && check(i + 1);
      check(0);

  local jsonnetKeywords = [
    'assert',
    'else',
    'error',
    'false',
    'for',
    'function',
    'if',
    'import',
    'importstr',
    'in',
    'local',
    'null',
    'self',
    'super',
    'tailstrict',
    'then',
    'true',
  ];
  local isJsonnetKeyword(s) = std.member(jsonnetKeywords, s);
  local isUnquotedFieldName(s) = isJsonnetIdent(s) && !isJsonnetKeyword(s);
  local objectField(name, expr) =
    if std.type(name) == 'string' && isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);
  local access(expr, name) =
    if isUnquotedFieldName(name) then j.Member(expr, name) else j.Index(expr, j.String(name));

  local pathParamInner(seg) =
    local len = std.length(seg);
    if len >= 2 && std.substr(seg, 0, 1) == '{' && std.substr(seg, len - 1, 1) == '}' then
      std.substr(seg, 1, len - 2)
    else null;
  local mangledPathVar(name) =
    if isJsonnetIdent(name) && !isJsonnetKeyword(name) then name
    else 'p_' + std.md5(name);
  local routeSegment(seg) =
    local inner = pathParamInner(seg);
    if inner == null then seg else '$' + mangledPathVar(inner);

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);
  local callPretty(expr, args, indent=0) = prettyApply(expr, args, indent);
  local emptyObject = j.Object([]);

  local pathExpr(op) =
    local fmt = std.get(op, 'pathFormat', '/');
    local ns = std.get(op, 'pathArgNames', []);
    if std.length(ns) == 0 then j.String(fmt)
    else j.Std.format(
      j.String(fmt),
      j.Array([
        j.Std.toString(access(j.Dollar, mangledPathVar(n)))
        for n in ns
      ])
    );

  local bucketExpr(bucketKey) =
    j.Std.get(j.Dollar, j.String(bucketKey)).default(emptyObject);
  local argField(bucketKey, p) =
    local bucket = bucketExpr(bucketKey);
    objectField(
      p.name,
      if p.required then j.Index(bucket, j.String(p.name))
      else j.Std.get(bucket, j.String(p.name)).default(j.Null)
    );
  local paramObject(bucketKey, params) =
    if std.length(params) == 0 then
      emptyObject
    else
      prettyObject([argField(bucketKey, p) for p in params], 6);

  local inputObject(op) =
    local q = std.get(op, 'queryParams', []);
    local h = std.get(op, 'headerParams', []);
    local base = [
      j.Field('method', j.String('GET')),
      j.Field('path', pathExpr(op)),
    ];
    local withQuery =
      if std.length(q) > 0 then base + [j.Field('query', paramObject('query', q))] else base;
    local withHeaders =
      if std.length(h) > 0 then withQuery + [j.Field('headers', paramObject('headers', h))] else withQuery;
    prettyObject(withHeaders, 6);

  local request(op) =
    callPretty(call(member(var('std'), 'native'), [j.String('invoke:' + service)]), [
      j.String('request'),
      prettyArray([inputObject(op)], 4),
    ], 4);

  local dataObject(expr) = prettyObject([j.Field('data', expr)], 2);
  local view(name) = member(member(var('a'), name), 'view');
  local node(path, body, viewExpr) = j.Array([
    j.Array([j.String(p) for p in path]),
    body,
    viewExpr,
  ]);
  local operationNode(path, op) =
    node(
      [service] + [routeSegment(p) for p in path] + ['resource'],
      dataObject(request(op)),
      view('resource')
    );
  local hasRequiredParams(params) =
    std.length([p for p in params if p.required]) > 0;
  local isResourceOperation(op) =
    !hasRequiredParams(std.get(op, 'queryParams', [])) &&
    !hasRequiredParams(std.get(op, 'headerParams', []));

  local childrenOf(node) = std.get(node, 'children', {});
  local childKeys(node) = std.sort(std.objectFields(childrenOf(node)));
  local operationNodes(node, path=[]) =
    (if std.get(node, 'operation', null) != null && isResourceOperation(node.operation) then [operationNode(path, node.operation)] else []) +
    std.flattenArrays([
      operationNodes(childrenOf(node)[k], if k == '_' then path else path + [k])
      for k in childKeys(node)
    ]);

  local generated = j.Locals([
    j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet')),
  ], prettyArray(operationNodes(spec.paths)));

  if manifest then j.manifestJsonnet(generated) else generated;

local graph = {
  manifest: true,
  data: {
    spec: openapi.nestedSpec($.spec),
  },
  _view:: {
    jsonnet: generate($.service, $.data.spec, $.manifest),
  },
};

{
  graph: graph,
}
