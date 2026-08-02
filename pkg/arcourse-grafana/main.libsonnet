local a = import '../arcourse-echarts/main.libsonnet';

local request(input) = std.native('invoke:grafana')('request', [input]);

local refId(i) = std.char(std.codepoint('A') + i);

local queryDefaults = { instant: false, range: !self.instant };

local query(datasource, queries, from='now-1h', to='now') =
  local reqQueries = [
    queryDefaults + queries[i] { refId: refId(i) }
    for i in std.range(0, std.length(queries) - 1)
  ];
  request({
    method: 'POST',
    path: '/api/ds/query',
    readonly: true,
    context: { datasource: datasource },
    body: { queries: reqQueries, from: from, to: to },
  });

local seriesName(frame) =
  std.get(frame.schema.fields[1].config, 'displayNameFromDS', frame.schema.refId);

local round(v, decimals) =
  if decimals == null then v
  else
    local factor = std.pow(10, decimals);
    std.round(v * factor) / factor;

local seriesFromFrames(frames, type, decimals) = [
  {
    name: seriesName(frame),
    type: type,
    showSymbol: false,
    data: [
      [frame.data.values[0][j], round(frame.data.values[1][j], decimals)]
      for j in std.range(0, std.length(frame.data.values[0]) - 1)
    ],
  }
  for frame in frames
];

local chartNode = a.chart.view {
  type:: 'line',
  decimals:: 2,
  data: query($.datasource, $.queries, std.get($, 'from', 'now-1h'), std.get($, 'to', 'now')),
  option::
    local results = $.data.results;
    local allSeries = std.flattenArrays([
      seriesFromFrames(results[refId(i)].frames, $.type, $.decimals)
      for i in std.range(0, std.length($.queries) - 1)
    ]);
    {
      title: { text: $.title },
      tooltip: { trigger: 'axis' },
      legend: { data: [s.name for s in allSeries], type: 'scroll', bottom: 0 },
      grid: { top: 40, bottom: 40, containLabel: true },
      xAxis: { type: 'time' },
      yAxis: { type: 'value' },
      series: allSeries,
    },
};

local collectQueries(node) =
  if node.type == 'panel' then node.chart.queries
  else std.flattenArrays([collectQueries(child) for child in node.children]);

local remapResults(results, offset, count) = {
  [refId(i)]: results[refId(offset + i)]
  for i in std.range(0, count - 1)
};

local resolveTree(node, results, index) =
  if node.type == 'panel' then
    local count = std.length(node.chart.queries);
    local resolved = chartNode + node.chart { data: { results: remapResults(results, index, count) } };
    { node: node { chart: resolved.option }, next: index + count }
  else
    local acc = std.foldl(
      function(acc, child)
        local r = resolveTree(child, results, acc.next);
        { children: acc.children + [r.node], next: r.next },
      node.children,
      { children: [], next: index }
    );
    { node: node { children: acc.children }, next: acc.next };

local dashboardNode = a.dashboard.view {
  local n = self,
  layout:: error 'Dashboard requires layout',
  data: query(n.datasource, collectQueries(n.layout), std.get(n, 'from', 'now-1h'), std.get(n, 'to', 'now')),
  tree:: resolveTree(n.layout, n.data.results, 0).node,
};

{
  chart: { node: chartNode },
  dashboard: { node: dashboardNode },
}
