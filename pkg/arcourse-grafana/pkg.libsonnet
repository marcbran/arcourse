local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-grafana',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-grafana',
  path: 'arcourse/arcourse-grafana',
  target: 'arcourse-grafana',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-time', 'v0.0.0'),
    p.plugin.github('marcbran/jsonnet-plugin-html', 'v0.0.0'),
  ],
  external: ['root'],
}, |||
  Generates an arcourse graph for browsing Grafana datasources and rendering their
  query results as arcourse-echarts charts and dashboards.

  Queries a datasource's `/api/ds/query` endpoint (via the host's `grafana`
  invocation), resolving relative time ranges (via jsonnet-plugin-time), and wires
  the results into `chart`/`dashboard` nodes, alongside `list`/`labels`/`values`
  nodes for browsing metrics and label values.
|||, {
  graph: p.desc(|||
    Root graph function. `datasourceNames` are the Grafana datasource names to
    expose as browsable `metrics`/labels/values routes.
  |||),
  chart: p.desc('Node rendering a single time series query as a line chart, with a time-range nav.'),
  dashboard: p.desc('Node rendering a `layout` of queries (see arcourse-echarts) as a dashboard, with a time-range nav.'),
  list: p.desc('Node listing distinct values of `label` for the metric matched by `expr`, linked via `link`.'),
  labels: p.desc('Node listing label names present on the metric matched by `expr`, linked via `link`.'),
  values: p.desc('Node rendering distinct values of `label` for the metric matched by `expr` as YAML.'),
})
