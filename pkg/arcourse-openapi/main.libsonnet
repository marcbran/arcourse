local j = import 'jsonnet/main.libsonnet';
local openapi = import 'openapi/main.libsonnet';

local generate(service, spec, links=[], columns=[], contextParams=[], manifest=true, pagination=null) =
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
  local contextPrefix = ['$' + mangledPathVar(p) for p in contextParams];

  local collectionFor(sourcePath) =
    local matching = [c for c in columns if c.sourcePath == sourcePath];
    if std.length(matching) > 0 then matching[0] else null;

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

  local paramsExpr = access(j.Dollar, '_params');
  local argField(p) = objectField(p.name, j.Std.get(paramsExpr, j.String(p.name)).default(j.Null));
  local paramObject(params) =
    if std.length(params) == 0 then
      emptyObject
    else
      prettyObject([argField(p) for p in params], 6);

  local contextObject =
    if std.length(contextParams) == 0 then null
    else prettyObject([
      objectField(p, access(j.Dollar, mangledPathVar(p)))
      for p in contextParams
    ], 6);
  local inputObject(op) =
    local q = std.get(op, 'queryParams', []);
    local h = std.get(op, 'headerParams', []);
    local base = [
      j.Field('method', j.String('GET')),
      j.Field('path', pathExpr(op)),
    ];
    local withQuery =
      if std.length(q) > 0 then base + [j.Field('query', paramObject(q))] else base;
    local withHeaders =
      if std.length(h) > 0 then withQuery + [j.Field('headers', paramObject(h))] else withQuery;
    local withContext =
      if contextObject == null then withHeaders else withHeaders + [j.Field('context', contextObject)];
    prettyObject(withContext, 6);

  local request(op) =
    callPretty(var('request'), [inputObject(op)], 4);
  local requestFunctionBind =
    j.LocalFunctionBind(
      'request',
      [j.Parameter('input')],
      call(call(member(var('std'), 'native'), [j.String('invoke:' + service)]), [
        j.String('request'),
        j.Array([var('input')]),
      ])
    );

  local paramSegments(link) = [seg for seg in link.value if std.objectHas(seg, 'param')];
  local linksFor(op) = [
    link
    for link in links
    if link.sourcePath == templatePath(op)
  ];
  local compactLiteral(value) =
    if value == null then j.Null
    else if std.type(value) == 'string' then j.String(value)
    else if std.type(value) == 'boolean' then if value then j.True else j.False
    else if std.type(value) == 'number' then j.Number(std.toString(value))
    else if std.type(value) == 'array' then j.Array([compactLiteral(item) for item in value])
    else if std.type(value) == 'object' then j.Object([
      objectField(field, compactLiteral(value[field]))
      for field in std.objectFields(value)
    ])
    else error 'unsupported literal type: ' + std.type(value);
  local paramSpecEntry(p) =
    { name: p.name, type: 'string' } + (if p.required then {} else { default: null });
  local paramSpecsFor(op) =
    std.get(op, 'queryParams', []) + std.get(op, 'headerParams', []);
  local paramSpecsField(op) =
    local specs = paramSpecsFor(op);
    if std.length(specs) == 0 then null
    else j.Field('_paramSpecs', prettyArray([compactLiteral(paramSpecEntry(p)) for p in specs], 4));
  local columnsFor(op) =
    local entry = collectionFor(templatePath(op));
    if entry == null then null else std.get(entry, 'columns', null);
  local defaultColumns(op) =
    local ls = linksFor(op);
    if std.length(ls) == 0 then null
    else
      local segs = paramSegments(ls[0]);
      if std.length(segs) == 0 then null
      else [
        {
          label: segs[i].param,
          path: segs[i].path,
        }
        for i in std.range(0, std.length(segs) - 1)
      ];
  local columnsForOp(op) =
    local explicit = columnsFor(op);
    if explicit != null then explicit
    else
      local d = defaultColumns(op);
      if d != null then d else [];
  local columnLiteral(col) = compactLiteral({ label: col.label, path: col.path });
  local resourceColumns(op) =
    local cols = columnsForOp(op);
    if std.length(cols) == 0 then null
    else prettyArray([columnLiteral(col) for col in cols], 6);
  local nodeView(name) = member(member(var('a'), name), 'node');
  local listView(op) =
    if resourceColumns(op) != null then nodeView('table') else nodeView('list');
  local tableAt(op) =
    local ls = linksFor(op);
    if std.length(ls) > 0 then ls[0].at
    else
      local collection = collectionFor(templatePath(op));
      if collection != null then std.get(collection, 'array', []) else [];
  local tableField(op) =
    local cols = resourceColumns(op);
    if cols == null then null
    else j.Field('table', prettyObject([
      objectField('at', compactLiteral(tableAt(op))),
      j.Field('columns', cols),
    ], 4)) { Hide: 0 };
  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local responseField(expr) = j.Field('response', expr) { Hide: 0 };
  local selfResponse = member(j.Self, 'response');
  local withLinkPrefix(item) =
    item {
      value: [{ const: service }] +
             [{ origin: mangledPathVar(p) } for p in contextParams] +
             item.value,
    };
  local prettyEntry(item) =
    prettyObject([objectField(field, compactLiteral(item[field])) for field in ['at', 'keys', 'value']], 6);
  local linkSpecsField(items) =
    j.Field(
      'linkSpecs',
      prettyArray([prettyEntry(withLinkPrefix(item)) for item in items], 4)
    ) { Hide: 0 };
  local dataObject(op, expr) =
    local ls = linksFor(op);
    local specs = paramSpecsField(op);
    local fields = [dataField(access(expr, 'body'))] +
      (if std.length(ls) == 0 then [] else [linkSpecsField(ls)]) +
      (if specs == null then [] else [specs]);
    prettyObject(fields, 2);
  local listObject(op, expr) =
    local ls = linksFor(op);
    local table = tableField(op);
    local specs = paramSpecsField(op);
    local fields = [responseField(expr), dataField(access(selfResponse, 'body'))] +
      (if std.length(ls) == 0 then [] else [linkSpecsField(ls)]) +
      (if table != null then [table] else []) +
      (if specs == null then [] else [specs]);
    prettyObject(fields, 2);
  local resourceOperationNode(path, op) =
    j.Array([
      j.Array([j.String(p) for p in [service] + contextPrefix + [routeSegment(p) for p in path]]),
      j.Add(nodeView('resource'), dataObject(op, request(op))),
    ]);
  local listOperationNode(path, op) =
    j.Array([
      j.Array([j.String(p) for p in [service] + contextPrefix + [routeSegment(p) for p in path]]),
      j.Add(listView(op), listObject(op, request(op))),
    ]);
  local operationNodesForPath(path, op) =
    if collectionFor(templatePath(op)) != null then [listOperationNode(path, op)]
    else [resourceOperationNode(path, op)];
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

  local localsWithFodder(specs, body) =
    std.foldr(
      function(spec, acc)
        local node = j.Local(spec.bind, acc);
        if std.objectHas(spec, 'fodder') then node.fodder(spec.fodder) else node,
      specs,
      body
    );

  local aBind =
    if pagination == null then
      j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet'))
    else
      j.LocalBind('a', j.Add(var('base'), j.Object([
        j.Field('table', j.Add(access(var('base'), 'table'), j.Object([
          j.Field('node', j.Add(access(access(var('base'), 'table'), 'node'), var('withPagination'))),
        ]))),
      ])));

  local rawLocalSpecs = (
    if pagination == null then [] else [
      { bind: j.LocalBind('withPagination', j.parseJsonnet(pagination)) },
      { bind: j.LocalBind('base', j.Import('arcourse-ui/main.libsonnet')), fodder: j.Fodder.LineEnd(1, 0) },
    ]
  ) + [
    { bind: aBind },
    { bind: requestFunctionBind },
  ];
  local localSpecs = [
    rawLocalSpecs[i] + (
      if i == 0 then {}
      else { fodder: std.get(rawLocalSpecs[i], 'fodder', j.Fodder.LineEnd(0, 0)) }
    )
    for i in std.range(0, std.length(rawLocalSpecs) - 1)
  ];

  local generated = localsWithFodder(
    localSpecs,
    prettyArray(operationNodes(spec.paths)).fodder(j.Fodder.LineEnd(1, 0))
  );

  if manifest then j.manifestJsonnet(generated) else generated;

local graph = {
  manifest: true,
  contextParams: [],
  pagination: null,
  data: {
    spec: openapi.nestedSpec($.spec),
    links: std.get($, 'links', []),
    columns: std.get($, 'columns', []),
  },
  _view:: {
    jsonnet: generate($.service, $.data.spec, $.data.links, $.data.columns, $.contextParams, $.manifest, $.pagination),
  },
};

{
  graph: graph,
}
