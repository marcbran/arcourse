{
  local c = self,
  option:: error 'Chart requires option',
  links:: {},
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
                  var option = %s;
                  option.tooltip = Object.assign({}, option.tooltip, { trigger: 'item' });

                  chart.setOption(option);
                  window.addEventListener('resize', function () { chart.resize(); });

                  var links = %s;
                  // Click: toggle. Cmd/ctrl+click: toggle all (isolate this
                  // one / restore all). Shift+click: open link, same tab.
                  // Shift+cmd/ctrl+click: open link, new tab.
                  var shiftKey = false;
                  var cmdKey = false;
                  var prevSelected = {};
                  var suppress = false;
                  // Tracked ourselves instead of read from chart.getOption(),
                  // since ECharts only lazily populates legend[0].selected
                  // once the user has interacted with the legend at least once.
                  var currentSelected = {};
                  (option.legend.data || []).forEach(function (entry) {
                    currentSelected[typeof entry === 'string' ? entry : entry.name] = true;
                  });
                  chart.getZr().on('mousedown', function (e) {
                    var ev = e.event;
                    shiftKey = !!(ev && ev.shiftKey);
                    cmdKey = !!(ev && (ev.ctrlKey || ev.metaKey));
                    prevSelected = Object.assign({}, currentSelected);
                  });
                  chart.on('legendselectchanged', function (params) {
                    Object.assign(currentSelected, params.selected);
                    if (suppress) return;

                    function revertToggle() {
                      var toRestore = Object.assign({}, prevSelected);
                      suppress = true;
                      chart.setOption({ legend: { selected: toRestore } });
                      currentSelected = Object.assign({}, toRestore);
                      suppress = false;
                    }

                    if (shiftKey) {
                      if (links[params.name]) {
                        revertToggle();
                        if (cmdKey) window.open(links[params.name], '_blank');
                        else window.location.href = links[params.name];
                      } else {
                        revertToggle();
                      }
                      return;
                    }

                    if (cmdKey) {
                      var names = Object.keys(prevSelected);
                      var wasOnlyThisSelected = names.every(function (name) {
                        return name === params.name ? prevSelected[name] : !prevSelected[name];
                      });
                      var toApply = {};
                      if (wasOnlyThisSelected) {
                        names.forEach(function (name) { toApply[name] = true; });
                      } else {
                        names.forEach(function (name) { toApply[name] = name === params.name; });
                      }
                      suppress = true;
                      chart.setOption({ legend: { selected: toApply } });
                      currentSelected = Object.assign({}, toApply);
                      suppress = false;
                      return;
                    }
                  });

                  // Shift/shift+cmd on a data point mirrors the legend's
                  // link-opening behavior (same tab / new tab); plain and
                  // cmd-only clicks on items are left alone.
                  chart.on('click', function (params) {
                    if (params.componentType !== 'series' || !shiftKey) return;
                    var link = links[params.seriesName];
                    if (!link) return;
                    if (cmdKey) window.open(link, '_blank');
                    else window.location.href = link;
                  });
                }
                if (document.readyState === 'complete') init();
                else window.addEventListener('load', init);
              })();
            ||| % [
              c.id,
              std.manifestJsonMinified(c.darkTheme),
              std.manifestJsonMinified({ animation: false, backgroundColor: 'transparent' } + c.option),
              std.manifestJsonMinified(c.links),
            ],
          },
        ],
      },
    ],
  },
}
