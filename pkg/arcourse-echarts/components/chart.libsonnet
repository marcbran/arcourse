{
  local c = self,
  option:: error 'Chart requires option',
  links:: {},
  width:: '100%',
  height:: '400px',
  darkTheme:: {
    color: ['#4c657e', '#856350', '#677d67', '#78607b', '#44756f', '#84734c', '#546a78', '#774b4b'],
    backgroundColor: 'transparent',
    textStyle: { color: '#ccc' },
    title: { textStyle: { color: '#ccc' }, subtextStyle: { color: '#999' } },
    legend: { textStyle: { color: '#ccc' } },
    tooltip: { backgroundColor: '#333', borderColor: '#555', textStyle: { color: '#ccc' } },
    grid: { borderColor: '#444' },
    categoryAxis: {
      axisLine: { lineStyle: { color: '#666' } },
      axisLabel: { color: '#ccc' },
      splitLine: { lineStyle: { color: ['#333'] } },
    },
    valueAxis: {
      axisLine: { lineStyle: { color: '#666' } },
      axisLabel: { color: '#ccc' },
      splitLine: { lineStyle: { color: ['#333'] } },
    },
    pie: {
      itemStyle: { borderColor: 'transparent' },
      label: { color: '#ccc', textBorderColor: 'transparent', textBorderWidth: 0 },
      labelLine: { lineStyle: { color: '#666' } },
    },
  },
  local payload = {
    option: { animation: false, backgroundColor: 'transparent' } + c.option,
    theme: c.darkTheme,
    links: c.links,
  },
  local configJson = std.strReplace(std.manifestJsonMinified(payload), '<', '\\u003c'),
  html: [
    {
      element: 'echarts-chart',
      attributes: { style: 'display: block; box-sizing: border-box; width: %s; height: %s;' % [c.width, c.height] },
      children: [
        {
          element: 'script',
          attributes: { type: 'application/json', class: 'echarts-config' },
          children: [{ html: configJson }],
        },
      ],
    },
  ],
}
