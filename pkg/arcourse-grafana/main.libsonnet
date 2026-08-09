local a = import '../arcourse-echarts/main.libsonnet';
local ui = import '../arcourse-ui/main.libsonnet';
local root = import 'root';

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
  if v == null || decimals == null then v
  else
    local factor = std.pow(10, decimals);
    std.round(v * factor) / factor;

local seriesFromFrames(frames, type, decimals) = [
  {
    name: seriesName(frame),
    type: type,
    showSymbol: true,
    symbolSize: 16,
    itemStyle: { opacity: 0 },
    data: [
      [frame.data.values[0][j], round(frame.data.values[1][j], decimals)]
      for j in std.range(0, std.length(frame.data.values[0]) - 1)
    ],
  }
  for frame in frames
];

// Optional per-query link:: function(labels) node, keyed by legend name, so
// a legend entry can navigate to another arcourse node.
local linksFromFrames(frames, linkFn) =
  if linkFn == null then {}
  else {
    [seriesName(frame)]: linkFn(frame.schema.fields[1].labels)._queryPath
    for frame in frames
    if linkFn(frame.schema.fields[1].labels) != null
  };

// SI-prefix scale for a whole chart, picked once from the largest absolute
// value across all series so every line shares one unit/axis label.
local siPrefixes = [
  { factor: 1e12, suffix: 'TB' },
  { factor: 1e9, suffix: 'GB' },
  { factor: 1e6, suffix: 'MB' },
  { factor: 1e3, suffix: 'KB' },
  { factor: 1, suffix: 'B' },
];

local maxAbsValue(series) =
  std.foldl(
    function(acc, s) std.foldl(
      function(acc2, point) if point[1] == null then acc2 else std.max(acc2, std.abs(point[1])),
      s.data,
      acc
    ),
    series,
    0
  );

local siScale(maxAbs) =
  local matches = [p for p in siPrefixes if maxAbs >= p.factor];
  if std.length(matches) > 0 then matches[0] else siPrefixes[std.length(siPrefixes) - 1];

local scaleSeries(series, factor, decimals) = [
  s { data: [[point[0], round(if point[1] == null then null else point[1] / factor, decimals)] for point in s.data] }
  for s in series
];

local chartNode = a.chart.view {
  type:: 'line',
  decimals:: 2,
  unit:: null,
  data: query($.datasource, $.queries, std.get($, 'from', 'now-1h'), std.get($, 'to', 'now')),
  links::
    local results = $.data.results;
    std.foldl(
      function(acc, i) acc + linksFromFrames(results[refId(i)].frames, std.get($.queries[i], 'link', null)),
      std.range(0, std.length($.queries) - 1),
      {}
    ),
  option::
    local results = $.data.results;
    local rawSeries = std.flattenArrays([
      seriesFromFrames(results[refId(i)].frames, $.type, null)
      for i in std.range(0, std.length($.queries) - 1)
    ]);
    local scale = if $.unit == 'bytes' then siScale(maxAbsValue(rawSeries)) else { factor: 1, suffix: null };
    local allSeries = scaleSeries(rawSeries, scale.factor, $.decimals);
    {
      title: { text: $.title },
      tooltip: { trigger: 'axis' },
      legend: {
        data: [{ name: s.name, itemStyle: { opacity: 1 } } for s in allSeries],
        type: 'scroll',
        bottom: 0,
        icon: 'roundRect',
      },
      grid: { top: 40, bottom: 40, containLabel: true },
      xAxis: { type: 'time' },
      yAxis: { type: 'value' } + (
        if scale.suffix != null then { axisLabel: { formatter: '{value} ' + scale.suffix } } else {}
      ),
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

local dashboardNode = a.dashboard.view {
  local n = self,
  layout:: error 'Dashboard requires layout',
  data: query(n.datasource, collectQueries(n.layout), std.get(n, 'from', 'now-1h'), std.get(n, 'to', 'now')),
  tree:: resolveTree(n.layout, n.data.results, 0).node,
};

local instantFrames(datasource, expr, from='now-5m', to='now') =
  query(datasource, [{ expr: expr, instant: true, range: false }], from, to).results.A.frames;

local frameLabelValues(frames, label) = [
  v
  for frame in frames
  for v in [std.get(frame.schema.fields[1].labels, label, null)]
  if v != null
];

local frameLabelNames(frames) =
  std.set(std.flattenArrays([
    [k for k in std.objectFields(frame.schema.fields[1].labels) if k != '__name__']
    for frame in frames
  ]));

local defaultGroup(n) = n._pathTemplate[std.length(n._pathTemplate) - 1];

local listNode = ui.groupList.view {
  local n = self,
  expr:: error 'List requires expr',
  label:: error 'List requires label',
  link:: error 'List requires link',
  group:: defaultGroup(n),
  data: frameLabelValues(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local labelsNode = ui.groupList.view {
  local n = self,
  expr:: error 'Labels requires expr',
  link:: error 'Labels requires link',
  group:: defaultGroup(n),
  data: frameLabelNames(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now'))),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local valuesNode = ui.yaml.view {
  local n = self,
  expr:: error 'Values requires expr',
  label:: error 'Values requires label',
  data: frameLabelValues(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
};

local graph(datasourceNames) = [
  [['grafana']],
  [['grafana', 'datasources'], {
    data: datasourceNames,
    links: { [name]: root.grafana.datasource(name) for name in datasourceNames },
  }, ui.list.view],
  [['grafana', '$datasource']],
  [['grafana', '$datasource', 'metrics'], listNode {
    expr:: 'count by (__name__) ({__name__=~".+"})',
    label:: '__name__',
    link:: function(name) root.grafana.datasource($.datasource).metric(name),
  }],
  [['grafana', '$datasource', '$metric'], labelsNode {
    expr:: $.metric,
    group:: 'labels',
    link:: function(name) root.grafana.datasource($.datasource).metric($.metric).label(name),
  }],
  [['grafana', '$datasource', '$metric', '$label'], valuesNode {
    expr:: $.metric,
    label:: $.label,
  }],
];

{
  chart: { node: chartNode },
  dashboard: { node: dashboardNode },
  list: { node: listNode },
  labels: { node: labelsNode },
  values: { node: valuesNode },
  graph: graph,
}
