{
  local c = self,
  option:: error 'Chart requires option',
  id:: 'chart',
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
  html: {
    element: 'div',
    attributes: { style: 'width: 100%; height: 100%; box-sizing: border-box;' },
    children: [
      {
        element: 'div',
        attributes: { id: c.id, style: 'width: %s; height: %s;' % [c.width, c.height] },
      },
      {
        element: 'script',
        children: [
          {
            html: |||
              (function () {
                function init() {
                  var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                  var chart = echarts.init(document.getElementById('%s'), dark ? %s : null);
                  chart.setOption(%s);
                  window.addEventListener('resize', function () { chart.resize(); });
                }
                if (document.readyState === 'complete') init();
                else window.addEventListener('load', init);
              })();
            ||| % [
              c.id,
              std.manifestJsonMinified(c.darkTheme),
              std.manifestJsonMinified({ animation: false, backgroundColor: 'transparent' } + c.option),
            ],
          },
        ],
      },
    ],
  },
}
