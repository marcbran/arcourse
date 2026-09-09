local a = import '../../arcourse-echarts/main.libsonnet';

function(query, timeRange)
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

  a.chart.view {
    type:: 'line',
    decimals:: 2,
    unit:: null,
    datasource:: 'default',
    queries:: error 'Chart requires queries',
    _paramSpecs: timeRange.paramSpecs,
    _telemetryItems:: [
      { type: 'promql', expr: qr.expr, instant: std.get(qr, 'instant', false) }
      for qr in $.queries
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
      fragment: base { child:: [(timeRange.nav { from:: $._params.from, to:: $._params.to }).html, base.child] },
    },
  }
