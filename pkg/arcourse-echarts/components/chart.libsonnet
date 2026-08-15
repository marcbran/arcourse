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

                  option.brush = {
                    xAxisIndex: 'all',
                    brushStyle: {
                      color: 'rgba(255, 255, 255, 0.08)',
                      borderWidth: 0,
                    },
                  };
                  option.toolbox = { show: false };

                  chart.setOption(option);
                  window.addEventListener('resize', function () { chart.resize(); });

                  chart.dispatchAction({
                    type: 'takeGlobalCursor',
                    key: 'brush',
                    brushOption: { brushType: 'lineX', brushMode: 'single' },
                  });
                  // Drag-select a horizontal range to navigate to it as an
                  // absolute time range, mirroring Grafana's chart-drag zoom.
                  // brushSelected fires continuously while dragging, so it
                  // only tracks the pending range - navigation happens once,
                  // on mouseup, so it doesn't fire mid-drag.
                  var pendingRange = null;
                  chart.on('brushSelected', function (params) {
                    var batch = params.batch && params.batch[0];
                    var area = batch && batch.areas && batch.areas[0];
                    pendingRange = area && area.coordRange;
                  });
                  chart.getZr().on('mouseup', function () {
                    if (!pendingRange) return;
                    var range = pendingRange;
                    pendingRange = null;
                    var from = new Date(Math.min(range[0], range[1])).toISOString();
                    var to = new Date(Math.max(range[0], range[1])).toISOString();
                    var url = new URL(window.location.href);
                    url.searchParams.set('from', from);
                    url.searchParams.set('to', to);
                    window.location.href = url.toString();
                  });

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
