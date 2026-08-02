local c = import 'components/main.libsonnet';
local html = import 'github.com/marcbran/jsonnet/plugin/html/main.libsonnet';

local echartsSrc = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
local echartsScript = { element: 'script', attributes: { src: echartsSrc } };

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: c.page { fragment:: [echartsScript, n._view.fragment] },
    html: html.manifestHtml(self.page),
  },
};

local chartView = baseView {
  _view+:: {
    fragment:
      c.panel {
        style:: ' display: block; width: 100%; box-sizing: border-box;',
        child:: c.chart {
          option:: $.option,
          id:: std.get($, 'chartId', 'chart'),
          width:: std.get($, 'width', '100%'),
          height:: std.get($, 'height', '400px'),
        },
      },
  },
};

local dashboardView = baseView {
  _view+:: {
    fragment:
      c.panel {
        style:: ' display: block; width: 100%; box-sizing: border-box;',
        child:: c.dashboard {
          layout:: $.tree,
          height:: std.get($, 'height', '600px'),
        },
      },
  },
};

{
  default: { view: chartView },
  chart: { view: chartView },
  dashboard: { view: dashboardView },
  row(flex, children):: { type: 'row', flex: flex, children: children },
  column(flex, children):: { type: 'column', flex: flex, children: children },
  panel(flex, chart):: { type: 'panel', flex: flex, chart: chart },
}
