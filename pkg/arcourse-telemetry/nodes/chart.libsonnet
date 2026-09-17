local a = import '../../arcourse-echarts/main.libsonnet';
local time = import '../time/main.libsonnet';

function(query, timeRange)
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

  local minList(l) = std.foldl(function(a, b) if b < a then b else a, l[1:], l[0]);

  local stepFor(points) =
    local ts = [p[0] for p in points];
    local deltas = [ts[j + 1] - ts[j] for j in std.range(0, std.length(ts) - 2) if ts[j + 1] > ts[j]];
    if std.length(deltas) > 0 then minList(deltas) else 60000;

  local segmentsFor(points, step) =
    local active = [p for p in points if p[1] != null && p[1] != 0];
    if std.length(active) == 0 then []
    else
      local res = std.foldl(
        function(acc, p)
          local ts = p[0];
          local v = p[1];
          if acc.cur == null then acc { cur: { start: ts, end: ts + step, value: v } }
          else if v == acc.cur.value && ts <= acc.cur.end + step * 0.5 then acc { cur: acc.cur { end: ts + step } }
          else acc { segs: acc.segs + [acc.cur], cur: { start: ts, end: ts + step, value: v } },
        active,
        { segs: [], cur: null }
      );
      res.segs + (if res.cur != null then [res.cur] else []);

  local linksFromResult(result, linkFn, legendFormat) =
    if linkFn == null then {}
    else {
      [seriesName(s.labels, legendFormat)]: linkFn(s.labels)
      for s in result.series
      if hasPoints(s) && linkFn(s.labels) != null
    };

  {
    base: a.chart.view {
      local n = self,
      datasource:: 'default',
      queries:: error 'Chart requires queries',
      _paramSpecs: timeRange.paramSpecs,
      _telemetryItems:: [
        { type: 'promql', expr: qr.expr, instant: std.get(qr, 'instant', false) }
        for qr in n.queries
      ],
      data: query(n.datasource, n._telemetryItems, n._params.from, n._params.to),
      _view+:: {
        local baseFragment = super.fragment,
        fragment: baseFragment { child:: [(timeRange.nav { from:: n._params.from, to:: n._params.to }).html, baseFragment.child] },
      },
    },

    line: a.line.chart {
      local n = self,
      links: std.foldl(
        function(acc, i) acc + linksFromResult(
          n.data.results[i],
          std.get(n.queries[i], 'link', null),
          std.get(n.queries[i], 'legendFormat', null)
        ),
        std.range(0, std.length(n.queries) - 1),
        {}
      ),
      series:: std.flattenArrays([
        [
          { name: seriesName(s.labels, std.get(n.queries[i], 'legendFormat', null)), data: [[p[0], p[1]] for p in s.points] }
          for s in n.data.results[i].series
          if hasPoints(s)
        ]
        for i in std.range(0, std.length(n.queries) - 1)
      ]),
    },

    stateTimeline: a.stateTimeline.chart {
      local n = self,
      local render(template, labels, value) =
        if template != null then applyLegendFormat(template, labels + { value: std.toString(value) }) else null,
      local linkFor(linkFn, labels) = if linkFn == null then null else linkFn(labels),
      local rawSeries = std.flattenArrays([
        [
          {
            row: if n.rowBy != null then applyLegendFormat(n.rowBy, s.labels) else seriesName(s.labels, std.get(n.queries[i], 'legendFormat', null)),
            color: if n.colorBy != null then std.get(n.colors, applyLegendFormat(n.colorBy, s.labels), null) else null,
            linkNode: linkFor(std.get(n.queries[i], 'link', null), s.labels),
            labels: s.labels,
            segments: segmentsFor(s.points, stepFor(s.points)),
          }
          for s in n.data.results[i].series
          if hasPoints(s)
        ]
        for i in std.range(0, std.length(n.queries) - 1)
      ]),
      local active = [s for s in rawSeries if std.length(s.segments) > 0],
      rowBy:: null,
      colorBy:: null,
      colors:: {},
      labelBy:: null,
      tooltip:: null,
      timeFormat:: '2006-01-02 15:04',
      rows:: std.foldl(function(acc, s) if std.member(acc, s.row) then acc else acc + [s.row], active, []),
      links: std.foldl(function(acc, s) if s.linkNode != null then acc + { [s.row]: s.linkNode } else acc, active, {}),
      segments:: std.flattenArrays([
        [{
          row: s.row,
          start: seg.start,
          end: seg.end,
          color: s.color,
          label: render(n.labelBy, s.labels, seg.value),
          tooltip: render(n.tooltip, s.labels + { from: time.format(seg.start, n.timeFormat), to: time.format(seg.end, n.timeFormat) }, seg.value),
          link: if s.linkNode != null then s.linkNode._queryPath else null,
        } for seg in s.segments]
        for s in active
      ]),
    },
  }
