local chart = import 'nodes/chart.libsonnet';
local list = import 'nodes/list.libsonnet';
local dashboard = import 'nodes/dashboard.libsonnet';
local labels = import 'nodes/labels.libsonnet';
local values = import 'nodes/values.libsonnet';
local drilldown = import 'nodeLists/drilldown.libsonnet';
local entity = import 'nodeLists/entity.libsonnet';

{
  promql: {
    chart: {
      node: chart,
      drillDown: { nodeList: drilldown },
      entity: { nodeList: entity },
    },
    list: { node: list },
    labels: { node: labels },
    values: { node: values },
  },
  telemetry: {
    dashboard: { node: dashboard },
  },
}
