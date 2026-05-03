local j = import 'jsonnet/main.libsonnet';
local openapi = import 'openapi/main.libsonnet';

local generate(service, spec, links=[], manifest=true) =
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
  local prettyArrayComp(body, specs, indent=0) =
    j.ArrayComp(
      body,
      [
        if spec.__kind__ == 'ForSpec' then spec.forFodder(le(indent + 2))
        else if spec.__kind__ == 'IfSpec' then spec.ifFodder(le(indent + 2))
        else spec
        for spec in specs
      ]
    ).closeFodder(le(indent));
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [
        field { fodder: [le(indent + 2)] }
        for field in fields
      ],
      [
        if spec.__kind__ == 'ForSpec' then spec.forFodder(le(indent + 2))
        else if spec.__kind__ == 'IfSpec' then spec.ifFodder(le(indent + 2))
        else spec
        for spec in specs
      ]
    ).closeFodder(le(indent));
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
  local splitPath(path) = [part for part in std.split(path, '/') if part != ''];

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);
  local callPretty(expr, args, indent=0) = prettyApply(expr, args, indent);
  local emptyObject = j.Object([]);
  local literal(value, indent=0) =
    if value == null then j.Null
    else if std.type(value) == 'string' then j.String(value)
    else if std.type(value) == 'boolean' then if value then j.True else j.False
    else if std.type(value) == 'number' then j.Number(std.toString(value))
    else if std.type(value) == 'array' then prettyArray([literal(item, indent + 2) for item in value], indent)
    else if std.type(value) == 'object' then prettyObject([
      objectField(field, literal(value[field], indent + 2))
      for field in std.objectFields(value)
    ], indent)
    else error 'unsupported literal type: ' + std.type(value);

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
  local templatePath(op) =
    local fmt = std.get(op, 'pathFormat', '/');
    local ns = std.get(op, 'pathArgNames', []);
    local parts = std.split(fmt, '%s');
    if std.length(ns) == 0 then fmt
    else std.join('', [
      parts[i] + (if i < std.length(ns) then '{' + ns[i] + '}' else '')
      for i in std.range(0, std.length(parts) - 1)
    ]);

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

  local pathValue(expr, path) =
    std.foldl(function(acc, part) access(acc, part), path, expr);
  local dataArray(link) = pathValue(member(j.Dollar, 'data'), link.array);
  local itemValue(path) = pathValue(var('item'), path);
  local paramValue(link, param) =
    if std.objectHas(std.get(link, 'vars', {}), param) then itemValue(link.vars[param])
    else access(j.Dollar, mangledPathVar(param));
  local targetLink(link) =
    std.foldl(
      function(acc, part)
        local param = pathParamInner(part);
        if param == null then access(acc, part)
        else call(access(acc, mangledPathVar(param)), [paramValue(link, param)]),
      splitPath(link.targetPath),
      access(var('root'), service)
    );
  local targetParams(link) = [
    param
    for part in splitPath(link.targetPath)
    for param in [pathParamInner(part)]
    if param != null
  ];
  local objectHas(expr, field) =
    call(member(var('std'), 'objectHas'), [expr, j.String(field)]);
  local isObject(expr) =
    j.Eq(call(member(var('std'), 'type'), [expr]), j.String('object'));
  local itemPathGuard(path) =
    local guard(expr, parts) =
      if std.length(parts) == 0 then j.Neq(expr, j.Null)
      else
        local next = access(expr, parts[0]);
        j.And(
          j.And(
            j.Neq(expr, j.Null),
            j.And(isObject(expr), objectHas(expr, parts[0]))
          ),
          guard(next, std.slice(parts, 1, std.length(parts), 1))
        );
    guard(var('item'), path);
  local linkGuard(link) =
    local guards = [
      itemPathGuard(link.vars[param])
      for param in std.objectFields(std.get(link, 'vars', {}))
      if std.objectHas(std.get(link, 'vars', {}), param)
    ];
    if std.length(guards) == 0 then null
    else std.foldl(
      function(acc, guard) j.And(acc, guard),
      std.slice(guards, 1, std.length(guards), 1),
      guards[0]
    );
  local nestedLinkValue(link, params, index, indent=6) =
    if index >= std.length(params) then targetLink(link)
    else prettyObject([
      j.Field(
        j.Std.toString(paramValue(link, params[index])),
        nestedLinkValue(link, params, index + 1, indent + 2)
      ) { SuperSugar: index < std.length(params) - 1 },
    ], indent);
  local nestedLinkObject(link) =
    local params = targetParams(link);
    prettyObject([
      j.Field(
        j.Std.toString(paramValue(link, params[0])),
        nestedLinkValue(link, params, 1)
      ) { SuperSugar: std.length(params) > 1 },
    ], 6);
  local mergeLink(link) =
    j.Add(var('acc'), nestedLinkObject(link));
  local linkComprehension(link) =
    local guard = linkGuard(link);
    local body = if guard == null then mergeLink(link) else j.If(guard, mergeLink(link), var('acc'));
    callPretty(member(var('std'), 'foldl'), [
      j.Function([j.Parameter('acc'), j.Parameter('item')], body),
      dataArray(link),
      emptyObject,
    ], 4);
  local linkComprehensions(links) = [linkComprehension(link) for link in links];
  local linksExpr(links) =
    local exprs = linkComprehensions(links);
    std.foldl(
      function(acc, expr) j.Add(acc, expr),
      std.slice(exprs, 1, std.length(exprs), 1),
      exprs[0]
    );
  local linksFor(op) = [
    link
    for link in links
    if link.sourcePath == templatePath(op)
  ];
  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local dataObject(op, expr, hiddenData=false) =
    local links = linksFor(op);
    local fields = [dataField(expr, hiddenData)] +
      (if std.length(links) == 0 then [] else [j.Field('links', linksExpr(links))]);
    prettyObject(fields, 2);
  local view(name) = member(member(var('a'), name), 'view');
  local node(path, body, viewExpr) = j.Array([
    j.Array([j.String(p) for p in path]),
    body,
    viewExpr,
  ]);
  local emptyNode(path) = j.Array([
    j.Array([j.String(p) for p in path]),
    j.Object(),
  ]);
  local resourceOperationNode(path, op) =
    node(
      [service] + [routeSegment(p) for p in path] + ['resource'],
      dataObject(op, request(op)),
      view('resource')
    );
  local listOperationNode(path, op) =
    node(
      [service] + [routeSegment(p) for p in path],
      dataObject(op, request(op), hiddenData=true),
      view('list')
    );
  local operationNodesForPath(path, op) =
    if std.length(linksFor(op)) > 0 then [listOperationNode(path, op)]
    else [
      emptyNode([service] + [routeSegment(p) for p in path]),
      resourceOperationNode(path, op),
    ];
  local hasRequiredParams(params) =
    std.length([p for p in params if p.required]) > 0;
  local isResourceOperation(op) =
    !hasRequiredParams(std.get(op, 'queryParams', [])) &&
    !hasRequiredParams(std.get(op, 'headerParams', []));

  local childrenOf(node) = std.get(node, 'children', {});
  local childKeys(node) = std.sort(std.objectFields(childrenOf(node)));
  local operationNodes(node, path=[]) =
    (if std.get(node, 'operation', null) != null && isResourceOperation(node.operation) then operationNodesForPath(path, node.operation) else []) +
    std.flattenArrays([
      operationNodes(childrenOf(node)[k], if k == '_' then path else path + [k])
      for k in childKeys(node)
    ]);

  local generated = j.Locals(
    [j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet'))] +
    (if std.length(links) == 0 then [] else [j.LocalBind('root', j.Import('root'))]),
    prettyArray(operationNodes(spec.paths))
  );

  if manifest then j.manifestJsonnet(generated) else generated;

local graph = {
  manifest: true,
  data: {
    spec: openapi.nestedSpec($.spec),
    links: std.get($, 'links', []),
  },
  _view:: {
    jsonnet: generate($.service, $.data.spec, $.data.links, $.manifest),
  },
};

{
  graph: graph,
}
