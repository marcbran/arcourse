local j = import 'jsonnet/main.libsonnet';
local kubernetes = import 'kubernetes/main.libsonnet';

local resourceVerbs(resource) = std.get(resource, 'verbs', []);

local mergeResource(left, right) =
  if left.kind != right.kind then
    error 'conflicting kind for %s: %s vs %s' % [left.name, left.kind, right.kind]
  else
    left { namespaced: left.namespaced || right.namespaced, verbs: std.set(resourceVerbs(left) + resourceVerbs(right)) };

local dedupeResources(resources) =
  local byKey = std.foldl(
    function(acc, r)
      acc { [r.name]: if std.objectHas(acc, r.name) then mergeResource(acc[r.name], r) else r },
    resources,
    {}
  );
  [byKey[k] for k in std.sort(std.objectFields(byKey))];

local generate(resources, group, version) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([elem.fodder(le(indent + 2)) for elem in elements]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([field { fodder: [le(indent + 2)] } for field in fields]).closeFodder(le(indent));
  local prettyApply(target, args, indent=0) =
    j.Apply(target, [arg.fodder(le(indent + 2)) for arg in args]).rightFodder(le(indent));
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [field { fodder: [le(indent + 2)] } for field in fields],
      [spec.forFodder(le(indent + 2)) for spec in specs]
    ).closeFodder(le(indent));

  local isAsciiLetter(c) = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
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
    'assert', 'else', 'error', 'false', 'for', 'function', 'if',
    'import', 'importstr', 'in', 'local', 'null', 'self', 'super',
    'tailstrict', 'then', 'true',
  ];
  local isJsonnetKeyword(s) = std.member(jsonnetKeywords, s);
  local isUnquotedFieldName(s) = isJsonnetIdent(s) && !isJsonnetKeyword(s);
  local access(expr, name) =
    if isUnquotedFieldName(name) then j.Member(expr, name) else j.Index(expr, j.String(name));

  local contains(xs, x) = std.length([y for y in xs if y == x]) > 0;
  local hasVerb(resource, verb) = contains(resourceVerbs(resource), verb);
  local lowerKind(resource) = std.asciiLower(resource.kind);
  local hasDuplicateKind(resource) =
    std.length([r for r in resources if r.kind == resource.kind]) > 1;
  local resourcePrefix = if group == '' then [] else [group];
  local itemVar(resource) =
    local base =
      if hasDuplicateKind(resource) && group != '' then
        '%s%s' % [lowerKind(resource), std.substr(std.md5(group), 0, 8)]
      else
        lowerKind(resource);
    local candidate = if isUnquotedFieldName(base) then base else 'item';
    if isJsonnetKeyword(candidate) then candidate + 'Item' else candidate;
  local route(resource) =
    local candidate = resource.name;
    if candidate == itemVar(resource) then candidate + 'List' else candidate;

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);
  local callPretty(expr, args, indent=0) = prettyApply(expr, args, indent);
  local rootContext =
    call(member(member(var('root'), 'kubernetes'), 'context'), [access(j.Dollar, 'context')]);
  local metadata(expr) = member(expr, 'metadata');
  local itemNamespace = member(metadata(var('item')), 'namespace');
  local itemName = member(metadata(var('item')), 'name');
  local namespacedResourceLink(resource, namespaceExpr, nameExpr) =
    local namespaceNode = call(member(rootContext, 'namespace'), [namespaceExpr]);
    local base = if group == '' then namespaceNode else access(namespaceNode, group);
    call(member(base, itemVar(resource)), [nameExpr]);
  local clusterResourceLink(resource, nameExpr) =
    local base = if group == '' then rootContext else access(rootContext, group);
    call(member(base, itemVar(resource)), [nameExpr]);

  local apiPrefix =
    if group == '' then '/api/' + version
    else '/apis/' + group + '/' + version;

  local k8sGet(pathExpr) =
    call(member(var('kubernetes'), 'get'), [access(j.Dollar, 'context'), pathExpr]);
  local k8sNeatGet(pathExpr) =
    call(member(member(var('kubernetes'), 'neat'), 'get'), [access(j.Dollar, 'context'), pathExpr]);

  local staticPath(path) = j.String(path);
  local formatPath(fmt, args) = j.Std.format(j.String(fmt), j.Array(args));
  local toStr(expr) = j.Std.toString(expr);

  local clusterListPath(resource) = staticPath(apiPrefix + '/' + resource.name);
  local clusterDetailPath(resource) =
    formatPath(apiPrefix + '/' + resource.name + '/%s', [toStr(access(j.Dollar, itemVar(resource)))]);
  local namespacedAllPath(resource) = staticPath(apiPrefix + '/' + resource.name);
  local namespacedListPath(resource) =
    formatPath(apiPrefix + '/namespaces/%s/' + resource.name, [toStr(access(j.Dollar, 'namespace'))]);
  local namespacedDetailPath(resource) =
    formatPath(apiPrefix + '/namespaces/%s/' + resource.name + '/%s', [
      toStr(access(j.Dollar, 'namespace')),
      toStr(access(j.Dollar, itemVar(resource))),
    ]);

  local objectField(name, expr) =
    if isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);
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

  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local dataObject(expr) = prettyObject([dataField(expr)], 2);
  local listObject(dataExpr, linksExpr, columnsExpr=null) = prettyObject(
    [dataField(dataExpr, hidden=true), j.Field('links', linksExpr)] +
    (if columnsExpr != null then [j.Field('columns', columnsExpr) { Hide: 0 }] else []),
    2
  );
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

  local getItems(expr) = member(expr, 'items');

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
  local columnLiteral(col) = compactLiteral({ label: col.label, path: col.path });
  local resourceColumns(resource) =
    local cols = std.get(resource, 'columns', []);
    if std.length(cols) > 0 then
      prettyArray([columnLiteral(col) for col in cols], 4)
    else null;
  local listView(resource) =
    if std.length(std.get(resource, 'columns', [])) > 0 then view('table') else view('list');

  local namespacedAllList(resource) =
    local data = k8sGet(namespacedAllPath(resource));
    local items = getItems(member(j.Dollar, 'data'));
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
                j.Field(itemName, namespacedResourceLink(resource, itemNamespace, itemName)),
              ], 16)
            )
          ),
        ], 8)
      )
    );
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listObject(data, callPretty(member(var('std'), 'foldl'), [foldFn, items, j.Object()], 2), resourceColumns(resource)),
      listView(resource)
    );

  local namespacedList(resource) =
    local data = k8sGet(namespacedListPath(resource));
    local items = getItems(member(j.Dollar, 'data'));
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + [route(resource)],
      listObject(data, prettyObjectComp(
        [j.Field(itemName, namespacedResourceLink(resource, member(j.Dollar, 'namespace'), itemName))],
        [j.ForSpec('item', items)],
        4
      ), resourceColumns(resource)),
      listView(resource)
    );

  local namespacedDetail(resource) =
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + ['$' + itemVar(resource)],
      dataObject(k8sNeatGet(namespacedDetailPath(resource))),
      view('resource')
    );

  local clusterList(resource) =
    local data = k8sGet(clusterListPath(resource));
    local items = getItems(member(j.Dollar, 'data'));
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listObject(data, prettyObjectComp(
        [j.Field(itemName, clusterResourceLink(resource, itemName))],
        [j.ForSpec('item', items)],
        4
      ), resourceColumns(resource)),
      listView(resource)
    );

  local clusterDetail(resource) =
    node(
      ['kubernetes', '$context'] + resourcePrefix + ['$' + itemVar(resource)],
      dataObject(k8sNeatGet(clusterDetailPath(resource))),
      view('resource')
    );

  local resourceNodes(resource) =
    if resource.namespaced then
      (if hasVerb(resource, 'list') then [namespacedAllList(resource), namespacedList(resource)] else []) +
      (if hasVerb(resource, 'get') then [namespacedDetail(resource)] else [])
    else
      (if hasVerb(resource, 'list') then [clusterList(resource)] else []) +
      (if hasVerb(resource, 'get') then [clusterDetail(resource)] else []);

  local hasNamespacedResources = std.length([r for r in resources if r.namespaced]) > 0;
  local groupContextNodes = if group != '' then [emptyNode(['kubernetes', '$context', group])] else [];
  local groupNamespaceNodes =
    if group != '' && hasNamespacedResources
    then [emptyNode(['kubernetes', '$context', '$namespace', group])]
    else [];

  groupContextNodes +
  groupNamespaceNodes +
  std.flattenArrays([resourceNodes(r) for r in resources]);

local generateAll(groups, manifest=true) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([elem.fodder(le(indent + 2)) for elem in elements]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([field { fodder: [le(indent + 2)] } for field in fields]).closeFodder(le(indent));
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [field { fodder: [le(indent + 2)] } for field in fields],
      [spec.forFodder(le(indent + 2)) for spec in specs]
    ).closeFodder(le(indent));
  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);

  local contextsNode = j.Array([
    j.Array([j.String('kubernetes'), j.String('contexts')]),
    prettyObject([
      j.Field('data', call(member(var('kubernetes'), 'contexts'))),
      j.Field('links', prettyObjectComp(
        [j.Field(member(var('c'), 'name'), call(member(member(var('root'), 'kubernetes'), 'context'), [member(var('c'), 'name')]))],
        [j.ForSpec('c', member(j.Dollar, 'data'))],
        4
      )),
    ], 2),
    member(member(var('a'), 'list'), 'view'),
  ]);
  local contextNode = j.Array([
    j.Array([j.String('kubernetes'), j.String('$context')]),
    j.Object(),
  ]);

  local allRouteNodes = [contextsNode, contextNode] + std.flattenArrays([
    generate(g.resources, g.group, g.version)
    for g in groups
  ]);
  local generated = j.Locals(
    [
      j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet')),
      j.LocalBind('kubernetes', j.Import('kubernetes/main.libsonnet')),
      j.LocalBind('root', j.Import('root')),
    ],
    prettyArray(allRouteNodes)
  );
  if manifest then j.manifestJsonnet(generated) else generated;

local groupVersionFromSpec(specStr) =
  local spec = std.parseJson(specStr);
  local firstPath = std.objectFields(spec.paths)[0];
  local parts = [p for p in std.split(firstPath, '/') if p != ''];
  if parts[0] == 'api' then { group: '', version: parts[1] }
  else { group: parts[1], version: parts[2] };

local linksFromSpec(specStr) =
  local spec = std.parseJson(specStr);
  local suffix = '/{name}';
  local suffixLen = std.length(suffix);
  local endsWith(s) =
    std.length(s) >= suffixLen &&
    std.substr(s, std.length(s) - suffixLen, suffixLen) == suffix;
  [
    { sourcePath: std.substr(p, 0, std.length(p) - suffixLen), targetPath: p, array: ['items'], vars: { name: ['metadata', 'name'] } }
    for p in std.objectFields(spec.paths)
    if endsWith(p) && std.objectHas(spec.paths, std.substr(p, 0, std.length(p) - suffixLen))
  ];

local resourcesFromSpecAndLinks(specStr, links, columns, group) =
  local spec = std.parseJson(specStr);
  local effectiveLinks = if links != null then links else linksFromSpec(specStr);
  local isNamespacedPath(path) =
    std.length(std.findSubstr('/namespaces/{', path)) > 0;
  local resourceNameFromPath(path) =
    local parts = [p for p in std.split(path, '/') if p != ''];
    parts[std.length(parts) - 1];
  local findKind(path) =
    local pathEntry = std.get(spec.paths, path, {});
    local getOp = std.get(pathEntry, 'get', null);
    if getOp == null then null
    else std.get(getOp, 'x-kubernetes-group-version-kind', null);
  local defaultColumns(path) =
    [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
    (if isNamespacedPath(path) then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
    [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];
  local findColumns(path) =
    local matching = [c for c in columns if c.sourcePath == path];
    if std.length(matching) > 0 then matching[0].columns else defaultColumns(path);
  local resourceFromLink(link) =
    local name = resourceNameFromPath(link.sourcePath);
    local gvk = findKind(link.sourcePath);
    {
      name: name,
      kind: if gvk != null then gvk.kind else 'Unknown',
      namespaced: isNamespacedPath(link.sourcePath),
      verbs: ['get', 'list'],
      group: group,
      columns: findColumns(link.sourcePath),
    };
  dedupeResources([resourceFromLink(link) for link in effectiveLinks]);

local defaultColumns(namespaced) =
  [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
  (if namespaced then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
  [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];

local resourcesFromDiscovery(discovery, group, columns, links) =
  local groupVersion = if group == '' then 'v1' else group + '/' + discovery.groupVersion;
  local columnsForGroup = std.get(columns, groupVersion, []);
  local linksForGroup = std.get(links, groupVersion, null);
  local apiPrefix = if group == '' then '/api/' + discovery.groupVersion else '/apis/' + discovery.groupVersion;
  local isNamespaced(r) = r.namespaced;
  local sourcePath(r) = if isNamespaced(r) then apiPrefix + '/namespaces/{namespace}/' + r.name else apiPrefix + '/' + r.name;
  local findColumns(r) =
    local path = sourcePath(r);
    local matching = [c for c in columnsForGroup if c.sourcePath == path];
    if std.length(matching) > 0 then matching[0].columns else defaultColumns(isNamespaced(r));
  local effectiveLinks = if linksForGroup != null then linksForGroup else [];
  local linkedNames = std.set([
    local parts = [p for p in std.split(l.sourcePath, '/') if p != ''];
    parts[std.length(parts) - 1]
    for l in effectiveLinks
  ]);
  dedupeResources([
    r { group: group, columns: findColumns(r) }
    for r in discovery.resources
    if std.length(std.findSubstr('/', r.name)) == 0
  ]);

local mergeGroups(groups) =
  local byKey = std.foldl(
    function(acc, g)
      local key = g.group + '/' + g.version;
      acc {
        [key]: if std.objectHas(acc, key)
          then acc[key] { resources: dedupeResources(acc[key].resources + g.resources) }
          else g,
      },
    groups,
    {}
  );
  [byKey[k] for k in std.objectFields(byKey)];

local groupsFromContext(ctx, columns, links) =
  local core = kubernetes.get(ctx, '/api/v1');
  local apis = kubernetes.get(ctx, '/apis');
  [{ group: '', version: 'v1', resources: resourcesFromDiscovery(core, '', columns, links) }] + [
    local discovery = kubernetes.get(ctx, '/apis/' + g.preferredVersion.groupVersion);
    { group: g.name, version: g.preferredVersion.version, resources: resourcesFromDiscovery(discovery, g.name, columns, links) }
    for g in apis.groups
  ];

local graph = {
  manifest: true,
  contexts: error 'contexts is required',
  data:
    local columns = if std.objectHas(self, 'columns') then self.columns else {};
    local links = if std.objectHas(self, 'links') then self.links else {};
    {
      groups: mergeGroups(std.flattenArrays([
        groupsFromContext(ctx, columns, links)
        for ctx in $.contexts
      ])),
    },
  _view:: {
    jsonnet: generateAll($.data.groups, $.manifest),
  },
};

{
  graph: graph,
}
