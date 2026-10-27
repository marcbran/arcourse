local url = import 'url.libsonnet';

local walk(current, remaining) =
  if std.length(remaining) == 0 then
    if std.type(current) == 'array' then current else [current]
  else
    local next =
      if std.type(current) == 'object' then std.get(current, remaining[0], null)
      else null;
    if next == null then []
    else if std.type(next) == 'array' then
      std.flatMap(function(item) walk(item, remaining[1:]), next)
    else
      walk(next, remaining[1:]);

local itemPath(item, path) =
  std.foldl(
    function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
    path,
    item
  );

local keyLabels(keySegs, item) = [
  if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
  for seg in keySegs
];

local nestEntries(entries, depth) =
  local ending = [e for e in entries if std.length(e.labels) == depth];
  local deeper = std.sort([e for e in entries if std.length(e.labels) > depth], function(e) e.labels[depth]);
  local n = std.length(deeper);
  local starts = [i for i in std.range(0, n - 1) if i == 0 || deeper[i].labels[depth] != deeper[i - 1].labels[depth]];
  local bounds = starts + [n];
  local children = {
    [deeper[bounds[j]].labels[depth]]: nestEntries(deeper[bounds[j]:bounds[j + 1]], depth + 1)
    for j in std.range(0, std.length(starts) - 1)
  };
  if std.length(ending) == 0 then children
  else if n == 0 then ending[std.length(ending) - 1].value
  else ending[std.length(ending) - 1].value + children;

local splitPrefix(valueSegs) =
  if std.length(valueSegs) == 0 then { prefix: [], suffix: [] }
  else if std.objectHas(valueSegs[0], 'param') || std.objectHas(valueSegs[0], 'path') then { prefix: [], suffix: valueSegs }
  else
    local rest = splitPrefix(valueSegs[1:]);
    { prefix: [valueSegs[0]] + rest.prefix, suffix: rest.suffix };

local resolveBase(root, node, prefixSegs) =
  std.foldl(
    function(acc, seg)
      if std.objectHas(seg, 'const') then acc[seg.const]
      else acc[seg.origin](std.toString(node[seg.origin])),
    prefixSegs,
    root
  );

local resolveKey(spec, item) =
  if std.type(spec) == 'string' then spec
  else
    local raw = itemPath(item, spec.path);
    if std.objectHas(spec, 'transform') then spec.transform(raw) else raw;

local resolveFromBase(base, item, suffixSegs) =
  std.foldl(
    function(acc, seg)
      if std.objectHas(seg, 'param') then
        acc[resolveKey(seg.param, item)](std.toString(itemPath(item, seg.path)))
      else if std.objectHas(seg, 'const') then
        acc[seg.const]
      else
        acc[resolveKey(seg, item)],
    suffixSegs,
    base
  );

local resolvable(item, valueSegs) =
  std.all(
    [itemPath(item, seg.path) != null for seg in valueSegs if std.objectHas(seg, 'path')] +
    [
      itemPath(item, seg.param.path) != null
      for seg in valueSegs
      if std.objectHas(seg, 'param') && std.type(seg.param) == 'object'
    ]
  );

local resolveLiteralSegment(node, item, seg) =
  if std.objectHas(seg, 'const') then seg.const
  else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
  else resolveKey(seg, item);

local resolveLiteralSegments(node, item, segs) =
  std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

local resolveUrl(node, item, literal) =
  local query = std.get(literal, 'query', {});
  url({
    scheme: std.get(literal, 'scheme', null),
    host: resolveLiteralSegments(node, item, std.get(literal, 'host', [])),
    path: [resolveLiteralSegment(node, item, seg) for seg in std.get(literal, 'path', [])],
    params: { [k]: resolveLiteralSegments(node, item, query[k]) for k in std.objectFields(query) },
  });

local urlSegments(literal) =
  std.get(literal, 'host', []) + std.get(literal, 'path', [])
  + std.flattenArrays([literal.query[k] for k in std.objectFields(std.get(literal, 'query', {}))]);

local linkEntries(node, spec, root) =
  if std.type(spec.value) == 'object' then
    local segs = urlSegments(spec.value);
    [
      { labels: keyLabels(spec.keys, item), value: resolveUrl(node, item, spec.value) }
      for item in walk(node.data, spec.at)
      if resolvable(item, segs)
    ]
  else
    local split = splitPrefix(spec.value);
    local base = resolveBase(root, node, split.prefix);
    [
      { labels: keyLabels(spec.keys, item), value: resolveFromBase(base, item, split.suffix) }
      for item in walk(node.data, spec.at)
      if resolvable(item, spec.value)
    ];

local buildLinks(node, specs, root=import 'root') =
  nestEntries(std.flatMap(function(spec) linkEntries(node, spec, root), specs), 0);

local rowLinkSpec(specs, at) =
  local matches = [spec for spec in specs if spec.at == at];
  if std.length(matches) == 0 then null else matches[0];

local rowLinkFor(node, specs, at) =
  local spec = rowLinkSpec(specs, at);
  if spec == null then null
  else
    local links = std.get(node, 'links', {});
    local segs = if std.type(spec.value) == 'object' then urlSegments(spec.value) else spec.value;
    function(item)
      if !resolvable(item, segs) then null
      else
        std.foldl(
          function(acc, label) if std.type(acc) == 'object' then std.get(acc, label, null) else null,
          keyLabels(spec.keys, item),
          links
        );

{
  buildLinks: buildLinks,
  rowLinkFor: rowLinkFor,
  withLinkSpecs: {
    linkSpecs:: [],
    links: buildLinks(self, self.linkSpecs, import 'root'),
  },
}
