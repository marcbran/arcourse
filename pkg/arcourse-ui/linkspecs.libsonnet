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

local resolveTarget(root, node, item, valueSegs) =
  std.foldl(
    function(acc, seg)
      if std.objectHas(seg, 'const') then acc[seg.const]
      else if std.objectHas(seg, 'origin') then acc[seg.origin](std.toString(node[seg.origin]))
      else acc[seg.param](std.toString(itemPath(item, seg.path))),
    valueSegs,
    root
  );

local resolvable(item, valueSegs) =
  std.all([
    itemPath(item, seg.path) != null
    for seg in valueSegs
    if std.objectHas(seg, 'path')
  ]);

local buildLinks(node, specs, root=import 'root') =
  std.foldl(
    function(acc, spec)
      acc + walk(
        node.data,
        spec.at,
        function(item)
          if resolvable(item, spec.value)
          then nestKeys(spec.keys, item, resolveTarget(root, node, item, spec.value))
          else {}
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
  else function(item)
    if resolvable(item, spec.value) then resolveTarget(root, node, item, spec.value) else null;

{
  buildLinks: buildLinks,
  rowLinkFor: rowLinkFor,
  withLinkSpecs: {
    linkSpecs:: [],
    links: buildLinks(self, self.linkSpecs, import 'root'),
  },
}
