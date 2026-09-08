local a = import '../../arcourse-echarts/main.libsonnet';
local query = import '../query.libsonnet';
local timeRange = import '../timeRange.libsonnet';

local collectItems(node) =
  if node.type == 'panel' then node.chart._telemetryItems
  else std.flattenArrays([collectItems(child) for child in node.children]);

local resolveTree(node, results, index) =
  if node.type == 'panel' then
    local count = std.length(node.chart._telemetryItems);
    local resolved = node.chart { data: { results: results[index:index + count] } };
    { node: node { chart: { option: resolved.option, links: resolved.links } }, next: index + count }
  else
    local acc = std.foldl(
      function(acc, child)
        local r = resolveTree(child, results, acc.next);
        { children: acc.children + [r.node], next: r.next },
      node.children,
      { children: [], next: index }
    );
    { node: node { children: acc.children }, next: acc.next };

a.dashboard.view {
  local n = self,
  datasource:: 'default',
  layout:: error 'Dashboard requires layout',
  _paramSpecs: timeRange.paramSpecs,
  data: query(n.datasource, collectItems(n.layout), n._params.from, n._params.to),
  tree:: resolveTree(n.layout, n.data.results, 0).node,
  _view+:: {
    local base = super.fragment,
    fragment: base { child:: [(timeRange.nav { from:: n._params.from, to:: n._params.to }).html, base.child] },
  },
}
