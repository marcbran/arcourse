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

local namespaceLinkSpec = {
  at: ['metadata'],
  keys: [{ const: 'namespace' }],
  value: [{ const: 'kubernetes' }, { origin: 'context' }, { param: 'namespace', path: ['namespace'] }],
};

local ownerReferenceLinkSpec = {
  at: ['metadata', 'ownerReferences'],
  keys: [{ const: 'owner' }, { path: ['name'] }],
  value: [
    { const: 'kubernetes' },
    { origin: 'context' },
    { origin: 'namespace' },
    { path: ['apiVersion'], transform: "function(v) local p = std.split(v, '/'); if std.length(p) > 1 then p[0] else ''" },
    { param: { path: ['kind'], transform: 'std.asciiLower' }, path: ['name'] },
  ],
};

local generate(resources, group, links=[], globalLinkSpecs=[]) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([elem.fodder(le(indent + 2)) for elem in elements]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([field { fodder: [le(indent + 2)] } for field in fields]).closeFodder(le(indent));

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

  local contextOrigin = { origin: 'context' };
  local groupSegment = if group == '' then [] else [{ const: group }];
  local nameSegment(resource) = { param: itemVar(resource), path: ['metadata', 'name'] };
  local allNamespacesLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'namespace'] }, { path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin, { param: 'namespace', path: ['metadata', 'namespace'] }]
           + groupSegment + [nameSegment(resource)],
  };
  local singleNamespaceLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin, { origin: 'namespace' }] + groupSegment + [nameSegment(resource)],
  };
  local clusterLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin] + groupSegment + [nameSegment(resource)],
  };

  local apiPrefix(resource) =
    if group == '' then '/api/' + resource.version
    else '/apis/' + group + '/' + resource.version;

  local k8sNeatGet(pathExpr) =
    call(member(member(var('kubernetes'), 'neat'), 'get'), [access(j.Dollar, 'context'), pathExpr]);

  local staticPath(path) = j.String(path);
  local formatPath(fmt, args) = j.Std.format(j.String(fmt), j.Array(args));
  local toStr(expr) = j.Std.toString(expr);

  local clusterListPath(resource) = staticPath(apiPrefix(resource) + '/' + resource.name);
  local clusterDetailPath(resource) =
    formatPath(apiPrefix(resource) + '/' + resource.name + '/%s', [toStr(access(j.Dollar, itemVar(resource)))]);
  local namespacedAllPath(resource) = staticPath(apiPrefix(resource) + '/' + resource.name);
  local namespacedListPath(resource) =
    formatPath(apiPrefix(resource) + '/namespaces/%s/' + resource.name, [toStr(access(j.Dollar, 'namespace'))]);
  local namespacedDetailPath(resource) =
    formatPath(apiPrefix(resource) + '/namespaces/%s/' + resource.name + '/%s', [
      toStr(access(j.Dollar, 'namespace')),
      toStr(access(j.Dollar, itemVar(resource))),
    ]);

  local clusterDetailPathStr(resource) = apiPrefix(resource) + '/' + resource.name + '/{name}';
  local namespacedDetailPathStr(resource) = apiPrefix(resource) + '/namespaces/{namespace}/' + resource.name + '/{name}';

  local isNamespacesConst(seg) = std.objectHas(seg, 'const') && seg.const == 'namespaces';
  local resourceItemVarByName = { [r.name]: itemVar(r) for r in resources };
  local wellKnownItemVars = { namespaces: 'namespace', nodes: 'node' };
  local targetItemVarFor(name) =
    if std.objectHas(resourceItemVarByName, name) then resourceItemVarByName[name]
    else if std.objectHas(wellKnownItemVars, name) then wellKnownItemVars[name]
    else null;
  local renameParam(seg, name) = if std.objectHas(seg, 'param') then seg { param: name } else seg;
  local rewriteLinkValue(value) =
    local isCore = value[0].const == 'api';
    local targetGroupSegment = if isCore then [] else [value[1]];
    local afterPrefix = std.slice(value, if isCore then 2 else 3, std.length(value), 1);
    local hasNamespace = std.length(afterPrefix) >= 2 && isNamespacesConst(afterPrefix[0]);
    local namespaceValueSeg = if hasNamespace then renameParam(afterPrefix[1], 'namespace') else null;
    local afterNamespace = if hasNamespace then std.slice(afterPrefix, 2, std.length(afterPrefix), 1) else afterPrefix;
    if std.length(afterNamespace) == 0 then
      if namespaceValueSeg == null then null
      else [{ const: 'kubernetes' }, contextOrigin] + targetGroupSegment + [namespaceValueSeg]
    else
      local rawIdSeg = afterNamespace[std.length(afterNamespace) - 1];
      local rawResourceNameSeg = if std.length(afterNamespace) >= 2 then afterNamespace[std.length(afterNamespace) - 2] else null;
      local targetItemVar =
        if rawResourceNameSeg != null && std.objectHas(rawResourceNameSeg, 'const')
        then targetItemVarFor(rawResourceNameSeg.const)
        else null;
      if targetItemVar == null then null
      else
        [{ const: 'kubernetes' }, contextOrigin] +
        (if hasNamespace then [namespaceValueSeg] else []) +
        targetGroupSegment +
        [renameParam(rawIdSeg, targetItemVar)];
  local linksAt(path) =
    local candidates = [l { value: rewriteLinkValue(l.value) } for l in links if l.sourcePath == path];
    [l for l in candidates if l.value != null];

  local objectField(name, expr) =
    if isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);

  local compactLiteral(value) =
    if value == null then j.Null
    else if std.type(value) == 'string' then j.String(value)
    else if std.type(value) == 'boolean' then if value then j.True else j.False
    else if std.type(value) == 'number' then j.Number(std.toString(value))
    else if std.type(value) == 'array' then j.Array([compactLiteral(item) for item in value])
    else if std.type(value) == 'object' then j.Object([
      objectField(field, if field == 'transform' then j.parseJsonnet(value[field]) else compactLiteral(value[field]))
      for field in std.objectFields(value)
    ])
    else error 'unsupported literal type: ' + std.type(value);

  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local linkSpecEntry(spec) =
    prettyObject([objectField(field, compactLiteral(spec[field])) for field in ['at', 'keys', 'value']], 6);
  local dataObject(expr, linkSpecs=[]) = prettyObject(
    [dataField(expr)] +
    (if std.length(linkSpecs) > 0 then [j.Field('linkSpecs', prettyArray([linkSpecEntry(s) for s in linkSpecs], 4)) { Hide: 0 }] else []),
    2
  );
  local listObject(dataExpr, linkSpecs, columnsExpr=null) = prettyObject(
    [dataField(dataExpr), j.Field('linkSpecs', prettyArray([linkSpecEntry(s) for s in linkSpecs], 4)) { Hide: 0 }] +
    (if columnsExpr != null then [j.Field('table', prettyObject([
       j.Field('at', j.Array([j.String('items')])),
       j.Field('columns', columnsExpr),
     ], 4)) { Hide: 0 }] else []),
    2
  );
  local nodeView(name) = member(member(var('a'), name), 'node');
  local nodePath(path) = j.Array([j.String(p) for p in path]);
  local node(path, viewExpr, body) = j.Array([nodePath(path), j.Add(viewExpr, body)]);
  local emptyNode(path) = j.Array([nodePath(path), j.Object()]);

  local columnLiteral(col) = compactLiteral({ label: col.label, path: col.path });
  local resourceColumns(resource) =
    local cols = std.get(resource, 'columns', []);
    if std.length(cols) > 0 then
      prettyArray([columnLiteral(col) for col in cols], 4)
    else null;
  local listView(resource) =
    if std.length(std.get(resource, 'columns', [])) > 0 then nodeView('table') else nodeView('list');

  local namespacedAllList(resource) =
    local data = k8sNeatGet(namespacedAllPath(resource));
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [allNamespacesLinkSpec(resource)], resourceColumns(resource))
    );

  local namespacedList(resource) =
    local data = k8sNeatGet(namespacedListPath(resource));
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [singleNamespaceLinkSpec(resource)], resourceColumns(resource))
    );

  local namespacedDetail(resource) =
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + ['$' + itemVar(resource)],
      nodeView('resource'),
      dataObject(k8sNeatGet(namespacedDetailPath(resource)), globalLinkSpecs + linksAt(namespacedDetailPathStr(resource)))
    );

  local clusterList(resource) =
    local data = k8sNeatGet(clusterListPath(resource));
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [clusterLinkSpec(resource)], resourceColumns(resource))
    );

  local clusterDetail(resource) =
    node(
      ['kubernetes', '$context'] + resourcePrefix + ['$' + itemVar(resource)],
      nodeView('resource'),
      dataObject(k8sNeatGet(clusterDetailPath(resource)), globalLinkSpecs + linksAt(clusterDetailPathStr(resource)))
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

local generateAll(groups, manifest=true, globalLinkSpecs=[]) =
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
    j.Add(
      member(member(var('a'), 'list'), 'node'),
      prettyObject([
        j.Field('data', call(member(var('kubernetes'), 'contexts'))),
        j.Field('links', prettyObjectComp(
          [j.Field(member(var('c'), 'name'), call(member(member(var('root'), 'kubernetes'), 'context'), [member(var('c'), 'name')]))],
          [j.ForSpec('c', member(j.Dollar, 'data'))],
          4
        )),
      ], 2)
    ),
  ]);
  local contextNode = j.Array([
    j.Array([j.String('kubernetes'), j.String('$context')]),
    j.Object(),
  ]);

  local allRouteNodes = [contextsNode, contextNode] + std.flattenArrays([
    generate(g.resources, g.group, std.get(g, 'links', []), globalLinkSpecs)
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

local groupVersionFromKey(key) =
  local parts = [p for p in std.split(key, '/') if p != ''];
  if parts[0] == 'api' then { group: '', version: parts[1] }
  else { group: parts[1], version: parts[2] };

local linksFromSpec(spec) =
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

local resourceNameFromPath(path) =
  local parts = [p for p in std.split(path, '/') if p != ''];
  local last = parts[std.length(parts) - 1];
  local isParam(s) = std.length(s) >= 1 && std.substr(s, 0, 1) == '{';
  if isParam(last) then parts[std.length(parts) - 2] else last;

local isSubresourcePath(path) =
  local parts = [p for p in std.split(path, '/') if p != ''];
  std.length(parts) >= 2 &&
  parts[std.length(parts) - 2] == '{name}' &&
  std.substr(parts[std.length(parts) - 1], 0, 1) != '{';

local resourcesFromSpec(spec, group, version, columns, links) =
  local groupVersion = if group == '' then version else group + '/' + version;
  local columnsForGroup = std.get(columns, groupVersion, []);
  local linksForGroup = std.get(links, groupVersion, null);
  local effectiveLinks = if linksForGroup != null then linksForGroup else linksFromSpec(spec);
  local nodeLinks = if linksForGroup != null then linksForGroup else [];
  local isNamespacedPath(path) =
    std.length(std.findSubstr('/namespaces/{', path)) > 0;
  local apiPrefix = if group == '' then '/api/' + version else '/apis/' + group + '/' + version;
  local collectionPath(name, namespaced) =
    apiPrefix + (if namespaced then '/namespaces/{namespace}/' else '/') + name;
  local detailPath(name, namespaced) = collectionPath(name, namespaced) + '/{name}';
  local findKind(path) =
    local pathEntry = std.get(spec.paths, path, {});
    local getOp = std.get(pathEntry, 'get', null);
    if getOp == null then null
    else std.get(getOp, 'x-kubernetes-group-version-kind', null);
  local hasGet(path) =
    std.objectHas(spec.paths, path) && std.objectHas(spec.paths[path], 'get');
  local defaultColumns(namespaced) =
    [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
    (if namespaced then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
    [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];
  local findColumns(path, namespaced) =
    local matching = [c for c in columnsForGroup if c.sourcePath == path];
    if std.length(matching) > 0 then matching[0].columns else defaultColumns(namespaced);
  local resourceFromLink(link) =
    local name = resourceNameFromPath(link.sourcePath);
    local namespaced = isNamespacedPath(link.sourcePath);
    local gvk = findKind(link.sourcePath);
    {
      name: name,
      kind: if gvk != null then gvk.kind else 'Unknown',
      namespaced: namespaced,
      verbs: (if hasGet(collectionPath(name, namespaced)) then ['list'] else []) + (if hasGet(detailPath(name, namespaced)) then ['get'] else []),
      group: group,
      version: version,
      columns: findColumns(collectionPath(name, namespaced), namespaced),
    };
  {
    resources: dedupeResources([
      resourceFromLink(link)
      for link in effectiveLinks
      if !isSubresourcePath(link.sourcePath)
    ]),
    links: nodeLinks,
  };

local defaultColumns(namespaced) =
  [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
  (if namespaced then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
  [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];

local resourcesFromDiscovery(discovery, group, columns, links) =
  local groupVersion = if group == '' then 'v1' else discovery.groupVersion;
  local bareVersion =
    local parts = std.split(discovery.groupVersion, '/');
    parts[std.length(parts) - 1];
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
  {
    resources: dedupeResources([
      r { group: group, version: bareVersion, columns: findColumns(r) }
      for r in discovery.resources
      if std.length(std.findSubstr('/', r.name)) == 0
    ]),
    links: effectiveLinks,
  };

local mergeGroups(groups) =
  local byKey = std.foldl(
    function(acc, g)
      local key = g.group;
      acc {
        [key]: if std.objectHas(acc, key)
          then acc[key] {
            resources: dedupeResources(acc[key].resources + g.resources),
            links: std.get(acc[key], 'links', []) + std.get(g, 'links', []),
          }
          else g,
      },
    groups,
    {}
  );
  [byKey[k] for k in std.objectFields(byKey)];

local groupVersionsOrdered(g) =
  [g.preferredVersion] + [v for v in g.versions if v.version != g.preferredVersion.version];

local groupsFromContext(ctx, columns, links) =
  local core = kubernetes.get(ctx, '/api/v1');
  local apis = kubernetes.get(ctx, '/apis');
  local coreResult = resourcesFromDiscovery(core, '', columns, links);
  [{ group: '', resources: coreResult.resources, links: coreResult.links }] + std.flattenArrays([
    [
      local discovery = kubernetes.get(ctx, '/apis/' + v.groupVersion);
      local result = resourcesFromDiscovery(discovery, g.name, columns, links);
      { group: g.name, resources: result.resources, links: result.links }
      for v in groupVersionsOrdered(g)
    ]
    for g in apis.groups
  ]);

local groupsFromSpecs(specs, columns, links) =
  mergeGroups([
    local gv = groupVersionFromKey(key);
    local result = resourcesFromSpec(specs[key], gv.group, gv.version, columns, links);
    { group: gv.group, resources: result.resources, links: result.links }
    for key in std.objectFields(specs)
  ]);

local graph = {
  manifest: true,
  contexts: [],
  specs: {},
  globalLinkSpecs: [namespaceLinkSpec, ownerReferenceLinkSpec],
  data:
    local columns = if std.objectHas(self, 'columns') then self.columns else {};
    local links = if std.objectHas(self, 'links') then self.links else {};
    {
      groups: mergeGroups(
        std.flattenArrays([groupsFromContext(ctx, columns, links) for ctx in $.contexts]) +
        groupsFromSpecs($.specs, columns, links)
      ),
    },
  _view:: {
    jsonnet: generateAll($.data.groups, $.manifest, $.globalLinkSpecs),
  },
};

{
  graph: graph,
}
