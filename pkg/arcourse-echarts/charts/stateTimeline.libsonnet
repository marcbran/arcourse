local common = import 'common.libsonnet';

{
  local c = self,
  title:: null,
  rows:: [],
  segments:: [],
  option::
    local rowIndex = { [c.rows[i]]: i for i in std.range(0, std.length(c.rows) - 1) };
    {
      title: { text: c.title },
      tooltip: { trigger: 'item' },
      grid: { top: 40, bottom: 40, containLabel: true },
      xAxis: common.timeAxis,
      yAxis: { type: 'category', data: c.rows },
      series: [{
        type: 'custom',
        renderItem: 'stateTimeline',
        encode: { x: [1, 2], y: 0 },
        data: [
          { value: [rowIndex[s.row], s.start, s.end] }
          + (if std.get(s, 'color', null) != null then { itemStyle: { color: s.color } } else {})
          for s in c.segments
        ],
      }],
    },
}
