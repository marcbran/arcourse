local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-echarts',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-echarts',
  path: 'arcourse/arcourse-echarts',
  target: 'arcourse-echarts',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-html', 'v0.0.0'),
  ],
}, |||
  Shared views for rendering arcourse graph nodes as ECharts charts and dashboards,
  built on top of jsonnet-plugin-html and arcourse-echarts' component library.

  `chart` renders a single `option` (an ECharts option object) as a chart panel.
  `dashboard` renders a `tree` of `row`/`column`/`panel` layouts as a grid of charts.
|||, {
  default: p.desc('Alias for `chart`. Fallback view.'),
  chart: p.desc('Renders `option` (an ECharts option object) as a single chart panel.'),
  dashboard: p.desc('Renders `tree` (built from `row`/`column`/`panel`) as a grid of charts.'),
  row: p.desc('Builds a horizontal `tree` layout entry with the given `flex` and `children`.'),
  column: p.desc('Builds a vertical `tree` layout entry with the given `flex` and `children`.'),
  panel: p.desc('Builds a leaf `tree` layout entry embedding a `chart` node with the given `flex`.'),
})
