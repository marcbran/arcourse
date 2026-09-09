local time = import 'time/main.libsonnet';
local telemetry = import 'telemetry/main.libsonnet';
local chain = import 'chain.libsonnet';
local timeRange = import 'timeRange.libsonnet';

local query = (import 'query.libsonnet')(time, telemetry);
local browse = (import 'browse.libsonnet')(query);

{
  promql: {
    chart: {
      node: (import 'nodes/chart.libsonnet')(query, timeRange),
      drillDown: { nodeList: (import 'nodeLists/drilldown.libsonnet')(chain, $.promql.chart.node) },
      entity: { nodeList: (import 'nodeLists/entity.libsonnet')(chain, $.promql.list.node, $.promql.chart.drillDown.nodeList) },
    },
    list: { node: (import 'nodes/list.libsonnet')(browse) },
    labels: { node: (import 'nodes/labels.libsonnet')(browse) },
    values: { node: (import 'nodes/values.libsonnet')(browse) },
  },
  telemetry: {
    dashboard: { node: (import 'nodes/dashboard.libsonnet')(query, timeRange) },
  },
}
