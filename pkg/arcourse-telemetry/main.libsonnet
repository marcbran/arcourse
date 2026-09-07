local a = import '../arcourse-echarts/main.libsonnet';
local ui = import '../arcourse-ui/main.libsonnet';
local time = import 'time/main.libsonnet';

local resolveTime(nowMs, value) =
  if value == 'now' then std.toString(nowMs)
  else if std.length(value) > 3 && std.substr(value, 0, 3) == 'now' then
    std.toString(time.addDuration(nowMs, std.substr(value, 3, std.length(value) - 3)))
  else
    std.toString(time.parseRFC3339(value));

local query(datasource, items, from='now-1h', to='now') =
  local nowMs = time.now();
  local resolvedFrom = resolveTime(nowMs, from);
  local resolvedTo = resolveTime(nowMs, to);
  std.native('invoke:telemetry')('query', [[
    item { datasource: datasource, from: resolvedFrom, to: resolvedTo }
    for item in items
  ]]);

local round(v, decimals) =
  if v == null || decimals == null then v
  else
    local factor = std.pow(10, decimals);
    std.round(v * factor) / factor;

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

local timeParamSpecs = [
  { name: 'from', type: 'string', default: 'now-1h' },
  { name: 'to', type: 'string', default: 'now' },
];

local timeRangeNavScript = importstr 'time-range-nav.js';

local timeRangeNav(from, to) = [
  { element: 'time-range-nav', attributes: { from: from, to: to } },
  { element: 'script', children: [{ html: timeRangeNavScript }] },
];

local defaultSeriesName(labels) =
  local name = std.get(labels, '__name__', null);
  local rest = std.join(', ', ['%s="%s"' % [k, labels[k]] for k in std.objectFields(labels) if k != '__name__']);
  if name != null && rest != '' then '%s{%s}' % [name, rest]
  else if name != null then name
  else if rest != '' then '{%s}' % rest
  else 'value';

local applyLegendFormat(legendFormat, labels) =
  std.foldl(
    function(acc, k) std.strReplace(acc, '{{%s}}' % k, labels[k]),
    std.objectFields(labels),
    legendFormat
  );

local seriesName(labels, legendFormat) =
  if legendFormat != null then applyLegendFormat(legendFormat, labels)
  else defaultSeriesName(labels);

local hasPoints(series) = std.length(series.points) > 0;

local seriesFromResult(result, type, decimals, legendFormat) = [
  {
    name: seriesName(s.labels, legendFormat),
    type: type,
    showSymbol: true,
    symbolSize: 16,
    itemStyle: { opacity: 0 },
    data: [[p[0], round(p[1], decimals)] for p in s.points],
  }
  for s in result.series
  if hasPoints(s)
];

local linksFromResult(result, linkFn, legendFormat) =
  if linkFn == null then {}
  else {
    [seriesName(s.labels, legendFormat)]: linkFn(s.labels)._queryPath
    for s in result.series
    if hasPoints(s) && linkFn(s.labels) != null
  };

local promqlChartNode = a.chart.view {
  type:: 'line',
  decimals:: 2,
  unit:: null,
  datasource:: 'default',
  queries:: error 'Chart requires queries',
  _paramSpecs: timeParamSpecs,
  _telemetryItems:: [
    { type: 'promql', expr: q.expr, instant: std.get(q, 'instant', false) }
    for q in $.queries
  ],
  data: query($.datasource, $._telemetryItems, $._params.from, $._params.to),
  links::
    std.foldl(
      function(acc, i) acc + linksFromResult(
        $.data.results[i],
        std.get($.queries[i], 'link', null),
        std.get($.queries[i], 'legendFormat', null)
      ),
      std.range(0, std.length($.queries) - 1),
      {}
    ),
  option::
    local rawSeries = std.flattenArrays([
      seriesFromResult($.data.results[i], $.type, null, std.get($.queries[i], 'legendFormat', null))
      for i in std.range(0, std.length($.queries) - 1)
    ]);
    local scale = if $.unit == 'bytes' then siScale(maxAbsValue(rawSeries)) else { factor: 1, suffix: null };
    local allSeries = scaleSeries(rawSeries, scale.factor, $.decimals);
    {
      title: { text: $.title },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'cross', z: 100, lineStyle: { color: '#888', type: 'dashed' } },
      },
      legend: {
        data: [{ name: s.name, itemStyle: { opacity: 1 } } for s in allSeries],
        type: 'scroll',
        bottom: 0,
        icon: 'roundRect',
      },
      grid: { top: 40, bottom: 40, containLabel: true },
      xAxis: {
        type: 'time',
        axisLabel: {
          formatter: {
            year: '{yyyy}',
            month: '{MMM}',
            day: '{MMM} {d}',
            hour: '{HH}:{mm}',
            minute: '{HH}:{mm}',
            second: '{HH}:{mm}:{ss}',
            none: '{yyyy}-{MM}-{dd}',
          },
        },
      },
      yAxis: { type: 'value' } + (
        if scale.suffix != null then { axisLabel: { formatter: '{value} ' + scale.suffix } } else {}
      ),
      series: allSeries,
    },
  _view+:: {
    local base = super.fragment,
    fragment: base { child:: [timeRangeNav($._params.from, $._params.to), base.child] },
  },
};

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

local dashboardNode = a.dashboard.view {
  local n = self,
  datasource:: 'default',
  layout:: error 'Dashboard requires layout',
  _paramSpecs: timeParamSpecs,
  data: query(n.datasource, collectItems(n.layout), n._params.from, n._params.to),
  tree:: resolveTree(n.layout, n.data.results, 0).node,
  _view+:: {
    local base = super.fragment,
    fragment: base { child:: [timeRangeNav(n._params.from, n._params.to), base.child] },
  },
};

local instantResult(datasource, expr, from='now-5m', to='now') =
  query(datasource, [{ type: 'promql', expr: expr, instant: true }], from, to).results[0];

local labelValues(result, label) = [
  v
  for s in result.series
  for v in [std.get(s.labels, label, null)]
  if v != null
];

local labelNames(result) =
  std.set(std.flattenArrays([
    [k for k in std.objectFields(s.labels) if k != '__name__']
    for s in result.series
  ]));

local defaultGroup(n) = n._pathTemplate[std.length(n._pathTemplate) - 1];

local listNode = ui.list.view {
  local n = self,
  datasource:: 'default',
  expr:: error 'List requires expr',
  label:: error 'List requires label',
  link:: error 'List requires link',
  group:: defaultGroup(n),
  data: labelValues(instantResult(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local labelsNode = ui.list.view {
  local n = self,
  datasource:: 'default',
  expr:: error 'Labels requires expr',
  link:: error 'Labels requires link',
  group:: defaultGroup(n),
  data: labelNames(instantResult(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now'))),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local valuesNode = ui.yaml.view {
  local n = self,
  datasource:: 'default',
  expr:: error 'Values requires expr',
  label:: error 'Values requires label',
  data: labelValues(instantResult(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
};

{
  promql: {
    chart: { node: promqlChartNode },
    list: { node: listNode },
    labels: { node: labelsNode },
    values: { node: valuesNode },
  },
  telemetry: {
    dashboard: { node: dashboardNode },
  },
}
