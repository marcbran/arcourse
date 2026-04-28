local j = import 'jsonnet/main.libsonnet';
local kubectl = import 'kubectl/main.libsonnet';

local generate(context, resources, manifest=true) =
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
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [
        field { fodder: [le(indent + 2)] }
        for field in fields
      ],
      [
        spec.forFodder(le(indent + 2))
        for spec in specs
      ]
    ).closeFodder(le(indent));

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
    if isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);
  local access(expr, name) =
    if isUnquotedFieldName(name) then j.Member(expr, name) else j.Index(expr, j.String(name));

  local contains(xs, x) = std.length([y for y in xs if y == x]) > 0;
  local hasVerb(resource, verb) = contains(std.get(resource, 'verbs', []), verb);
  local group(resource) = std.get(resource, 'group', '');
  local safeChar(c) =
    if isAsciiLetter(c) || isAsciiDigit(c) then std.asciiLower(c) else '-';
  local safeSegment(s) = std.join('', [safeChar(c) for c in std.stringChars(s)]);
  local lowerKind(resource) = std.asciiLower(resource.kind);
  local hasDuplicateKind(resource) =
    std.length([r for r in resources if r.kind == resource.kind]) > 1;
  local itemVar(resource) =
    local base =
      if hasDuplicateKind(resource) && group(resource) != '' then
        '%s%s' % [lowerKind(resource), std.substr(std.md5(group(resource)), 0, 8)]
      else
        lowerKind(resource);
    local candidate = if isUnquotedFieldName(base) then base else 'item';
    if isJsonnetKeyword(candidate) then candidate + 'Item' else candidate;
  local hasDuplicateName(resource) =
    std.length([r for r in resources if r.name == resource.name]) > 1;
  local route(resource) =
    if hasDuplicateName(resource) && group(resource) != '' then
      '%s-%s' % [resource.name, safeSegment(group(resource))]
    else
      resource.name;
  local queryResource(resource) =
    if hasDuplicateName(resource) && group(resource) != '' then
      '%s.%s' % [resource.name, group(resource)]
    else
      resource.name;

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);
  local callPretty(expr, args, indent=0) = prettyApply(expr, args, indent);
  local rootContext =
    call(member(member(var('root'), 'kubernetes'), 'context'), [member(j.Dollar, 'context')]);
  local metadata(expr) = member(expr, 'metadata');
  local itemNamespace = member(metadata(var('item')), 'namespace');
  local itemName = member(metadata(var('item')), 'name');
  local resourceNode(parent, resource) = access(parent, route(resource));
  local namespacedResourceLink(resource, namespaceExpr, nameExpr) =
    call(
      member(call(member(rootContext, 'namespace'), [namespaceExpr]), itemVar(resource)),
      [nameExpr]
    );
  local clusterResourceLink(resource, nameExpr) =
    call(member(rootContext, itemVar(resource)), [nameExpr]);

  local kubectlGet(options, resource, name=j.Null) =
    callPretty(member(member(var('kubectl'), 'neat'), 'get'), [
      options,
      j.String(queryResource(resource)),
      name,
    ], 4);
  local getItems(options, resource) = member(kubectlGet(options, resource), 'items');
  local options(fields) = prettyObject([j.Field(k, fields[k]) for k in std.objectFields(fields)], 4);
  local contextOptions(extra={}) = options({ context: member(j.Dollar, 'context') } + extra);
  local dataObject(expr) = prettyObject([j.Field('data', expr)], 2);
  local view(name) = member(member(var('a'), name), 'view');
  local node(path, body, viewExpr) = j.Array([
    j.Array([j.String(p) for p in path]),
    body,
    viewExpr,
  ]);

  local namespacedAllList(resource) =
    local items = getItems(contextOptions({ allNamespaces: j.True }), resource);
    local foldFn = j.Function(
      [j.Parameter('acc'), j.Parameter('item')],
      j.Add(
        var('acc'),
        prettyObject([
          j.Field(
            itemNamespace,
            j.Add(
              call(member(var('std'), 'get'), [var('acc'), itemNamespace, j.Object()]),
              prettyObject([
                j.Field(
                  itemName,
                  namespacedResourceLink(resource, itemNamespace, itemName)
                ),
              ], 16)
            )
          ),
        ], 8)
      )
    );
    node(
      ['kubernetes', '$context', route(resource)],
      dataObject(callPretty(member(var('std'), 'foldl'), [foldFn, items, j.Object()], 2)),
      view('list')
    );

  local namespacedList(resource) =
    local items = getItems(contextOptions({ namespace: member(j.Dollar, 'namespace') }), resource);
    node(
      ['kubernetes', '$context', '$namespace', route(resource)],
      dataObject(prettyObjectComp(
        [j.Field(
          itemName,
          namespacedResourceLink(resource, member(j.Dollar, 'namespace'), itemName)
        )],
        [j.ForSpec('item', items)],
        4
      )),
      view('list')
    );

  local namespacedDetail(resource) =
    node(
      ['kubernetes', '$context', '$namespace', '$' + itemVar(resource), 'resource'],
      dataObject(kubectlGet(
        contextOptions({ namespace: member(j.Dollar, 'namespace') }),
        resource,
        member(j.Dollar, itemVar(resource))
      )),
      view('resource')
    );

  local clusterList(resource) =
    local items = getItems(contextOptions(), resource);
    node(
      ['kubernetes', '$context', route(resource)],
      dataObject(prettyObjectComp(
        [j.Field(itemName, clusterResourceLink(resource, itemName))],
        [j.ForSpec('item', items)],
        4
      )),
      view('list')
    );

  local clusterDetail(resource) =
    node(
      ['kubernetes', '$context', '$' + itemVar(resource), 'resource'],
      dataObject(kubectlGet(contextOptions(), resource, member(j.Dollar, itemVar(resource)))),
      view('resource')
    );

  local resourceNodes(resource) =
    if resource.namespaced then
      (if hasVerb(resource, 'list') then [namespacedAllList(resource), namespacedList(resource)] else []) +
      (if hasVerb(resource, 'get') then [namespacedDetail(resource)] else [])
    else
      (if hasVerb(resource, 'list') then [clusterList(resource)] else []) +
      (if hasVerb(resource, 'get') then [clusterDetail(resource)] else []);

  local apiResourcesNode = node(
    ['kubernetes', '$context', 'api-resources'],
    dataObject(call(member(var('kubectl'), 'apiResources'), [
      contextOptions({ output: j.String('wide') }),
    ])),
    view('resource')
  );

  local generated = j.Locals([
    j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet')),
    j.LocalBind('kubectl', j.Import('kubectl/main.libsonnet')),
    j.LocalBind('root', j.Import('root')),
  ], prettyArray([apiResourcesNode] + std.flattenArrays([resourceNodes(r) for r in resources])));

  if manifest then j.manifestJsonnet(generated) else generated;

local graph = {
  manifest: true,
  data: {
    resources: kubectl.apiResources({ context: $.context, output: 'wide' }),
  },
  _view:: {
    jsonnet: generate($.context, $.data.resources, $.manifest),
  },
};

{
  graph: graph,
}
