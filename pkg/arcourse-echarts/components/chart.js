class EchartsChart extends HTMLElement {
  connectedCallback() {
    var self = this;
    if (document.readyState === 'complete') self.init();
    else window.addEventListener('load', function () { self.init(); }, { once: true });
  }

  disconnectedCallback() {
    if (this._resize) window.removeEventListener('resize', this._resize);
    if (this._chart) this._chart.dispose();
  }

  init() {
    var configEl = this.querySelector(':scope > script.echarts-config');
    if (!configEl) return;
    var config = JSON.parse(configEl.textContent);
    var option = config.option;
    var links = config.links || {};

    var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    var chart = echarts.init(this, dark ? config.theme : null);
    this._chart = chart;

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
    this._resize = function () { chart.resize(); };
    window.addEventListener('resize', this._resize);

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
    ((option.legend && option.legend.data) || []).forEach(function (entry) {
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
}

if (!customElements.get('echarts-chart')) {
  customElements.define('echarts-chart', EchartsChart);
}
