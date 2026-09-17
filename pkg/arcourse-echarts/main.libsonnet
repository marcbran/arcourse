local c = import 'components/main.libsonnet';
local ui = import '../arcourse-ui/components/main.libsonnet';
local html = import 'html/main.libsonnet';
local charts = import 'charts/main.libsonnet';

local echartsSrc = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
local echartsScript = { element: 'script', attributes: { src: echartsSrc } };
local componentScript = { element: 'script', children: [{ html: importstr 'components/chart.js' }] };

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: ui.page { fragment:: [echartsScript, componentScript, n._view.fragment] },
    html: html.manifestHtml(self.page),
  },
};

local linkPaths(links) = {
  [k]: links[k]._queryPath
  for k in std.objectFields(links)
  if std.isObject(links[k]) && std.objectHasAll(links[k], '_queryPath')
};

local chartView = baseView {
  _view+:: {
    fragment:
      c.panel {
        child:: c.chart {
          option:: $.option,
          links:: linkPaths(std.get($, 'links', {})),
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
} + charts
