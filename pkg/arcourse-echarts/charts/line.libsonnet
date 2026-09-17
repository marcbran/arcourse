local common = import 'common.libsonnet';

{
  local c = self,
  title:: null,
  series:: [],
  unit:: null,
  decimals:: 2,
  option::
    local styled = [
      s { type: 'line', showSymbol: true, symbolSize: 16, itemStyle: { opacity: 0 } }
      for s in c.series
    ];
    local scale = if c.unit == 'bytes' then common.siScale(common.maxAbsValue(styled)) else { factor: 1, suffix: null };
    local allSeries = common.scaleSeries(styled, scale.factor, c.decimals);
    {
      title: { text: c.title },
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
      xAxis: common.timeAxis,
      yAxis: { type: 'value' } + (
        if scale.suffix != null then { axisLabel: { formatter: '{value} ' + scale.suffix } } else {}
      ),
      series: allSeries,
    },
}
