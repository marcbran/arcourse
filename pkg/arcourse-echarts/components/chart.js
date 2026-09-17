function stateTimelineRenderItem(params, api) {
  var row = api.value(0);
  var start = api.coord([api.value(1), row]);
  var end = api.coord([api.value(2), row]);
  var height = api.size([0, 1])[1] * 0.6;
  return {
    type: 'rect',
    shape: {
      x: start[0],
      y: start[1] - height / 2,
      width: Math.max(end[0] - start[0], 1),
      height: height,
    },
    style: api.style(),
  };
}

var RENDERERS = { stateTimeline: stateTimelineRenderItem };

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

    (option.series || []).forEach(function (s) {
      if (typeof s.renderItem === 'string' && RENDERERS[s.renderItem]) {
        s.renderItem = RENDERERS[s.renderItem];
      }
    });

    chart.setOption(option);
    this._resize = function () { chart.resize(); };
    window.addEventListener('resize', this._resize);

    chart.dispatchAction({
      type: 'takeGlobalCursor',
      key: 'brush',
      brushOption: { brushType: 'lineX', brushMode: 'single' },
    });
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

    var shiftKey = false;
    var cmdKey = false;
    var prevSelected = {};
    var suppress = false;

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
