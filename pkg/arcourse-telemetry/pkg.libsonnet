local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-telemetry',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-telemetry',
  path: 'arcourse/arcourse-telemetry',
  target: 'arcourse-telemetry',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-time', 'v0.0.0'),
    p.plugin.github('marcbran/jsonnet-plugin-telemetry', 'v0.0.0'),
    p.plugin.github('marcbran/jsonnet-plugin-html', 'v0.0.0'),
  ],
}, |||
  Backend-agnostic `chart`/`dashboard` nodes rendering telemetry queries as
  arcourse-echarts charts and dashboards. Queries are batched through the
  host's `telemetry` invocation (see jsonnet-plugin-telemetry), resolving
  relative time ranges (via jsonnet-plugin-time).

  Each chart node queries exactly one telemetry type (a chart can't mix
  metric and log series in one rendering), but `dashboard.node` is type-
  agnostic and can lay out panels of different types side by side.
|||, {
  promql: p.desc(|||
    `chart`/`list`/`labels`/`values` nodes for PromQL-shaped telemetry
    queries, analogous to arcourse-grafana's nodes but querying the generic
    `telemetry` invocation with `type: 'promql'` items instead of talking to
    Grafana directly.
  |||),
  dashboard: p.desc(|||
    Node rendering a `layout` of panels (see arcourse-echarts) as a
    dashboard, with a time-range nav. Panels may come from any telemetry
    type's chart node - the dashboard only needs each panel's chart to
    expose `_telemetryItems` and its own `option`/`links` rendering.
  |||),
})
