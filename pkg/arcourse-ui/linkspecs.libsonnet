local walk(current, remaining, buildFn) =
  if std.length(remaining) == 0 then
    if std.type(current) == 'array' then
      std.foldl(function(acc, item) acc + buildFn(item), current, {})
    else buildFn(current)
  else
    local next =
      if std.type(current) == 'object' then std.get(current, remaining[0], null)
      else null;
    if next == null then {}
    else if std.type(next) == 'array' then
      std.foldl(function(acc, item) acc + walk(item, remaining[1:], buildFn), next, {})
    else
      walk(next, remaining[1:], buildFn);

local itemPath(item, path) =
  std.foldl(
    function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
    path,
    item
  );

local nestValue(labels, index, value) =
  if index == std.length(labels) - 1 then { [labels[index]]: value }
  else { [labels[index]]+: nestValue(labels, index + 1, value) };

local nestKeys(keySegs, item, value) =
  local labels = [
    if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
    for seg in keySegs
  ];
  nestValue(labels, 0, value);

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

local hexDigits = '0123456789ABCDEF';

local percentEncode(s) =
  std.join('', [
    local c = s[i];
    local cp = std.codepoint(c);
    if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)
       || c == '-' || c == '_' || c == '.' || c == '~'
    then c
    else '%' + hexDigits[std.floor(cp / 16)] + hexDigits[cp % 16]
    for i in std.range(0, std.length(s) - 1)
  ]);

local resolveLiteralSegment(node, item, seg) =
  if std.objectHas(seg, 'const') then seg.const
  else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
  else resolveKey(seg, item);

local resolveLiteralSegments(node, item, segs) =
  std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

local resolveQuery(node, item, queryObj) =
  local keys = std.objectFields(queryObj);
  if std.length(keys) == 0 then ''
  else '?' + std.join('&', [
    percentEncode(k) + '=' + percentEncode(resolveLiteralSegments(node, item, queryObj[k]))
    for k in keys
  ]);

local resolveUrl(node, item, url) =
  local scheme = std.get(url, 'scheme', null);
  local host = std.get(url, 'host', []);
  local path = std.get(url, 'path', []);
  local query = std.get(url, 'query', {});
  (if scheme != null then scheme + '://' else '')
  + resolveLiteralSegments(node, item, host)
  + (
      if std.length(path) > 0 then
        '/' + std.join('/', [percentEncode(resolveLiteralSegment(node, item, seg)) for seg in path])
      else ''
    )
  + resolveQuery(node, item, query);

local urlSegments(url) =
  std.get(url, 'host', []) + std.get(url, 'path', [])
  + std.flattenArrays([url.query[k] for k in std.objectFields(std.get(url, 'query', {}))]);

local buildLinks(node, specs, root=import 'root') =
  std.foldl(
    function(acc, spec)
      acc + (
        if std.type(spec.value) == 'object' then
          walk(
            node.data,
            spec.at,
            function(item)
              if resolvable(item, urlSegments(spec.value))
              then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
              else {}
          )
        else
          local split = splitPrefix(spec.value);
          local base = resolveBase(root, node, split.prefix);
          walk(
            node.data,
            spec.at,
            function(item)
              if resolvable(item, spec.value)
              then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
              else {}
          )
      ),
    specs,
    {}
  );

local rowLinkSpec(specs, at) =
  local matches = [spec for spec in specs if spec.at == at];
  if std.length(matches) == 0 then null else matches[0];

local rowLinkFor(node, specs, at, root=import 'root') =
  local spec = rowLinkSpec(specs, at);
  if spec == null then null
  else
    local split = splitPrefix(spec.value);
    local base = resolveBase(root, node, split.prefix);
    function(item)
      if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

{
  buildLinks: buildLinks,
  rowLinkFor: rowLinkFor,
  withLinkSpecs: {
    linkSpecs:: [],
    links: buildLinks(self, self.linkSpecs, import 'root'),
  },
}
