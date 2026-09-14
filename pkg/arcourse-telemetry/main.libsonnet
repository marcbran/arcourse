local time = import 'time/main.libsonnet';
local telemetry = import 'telemetry/main.libsonnet';
local chain = import 'chain.libsonnet';
local timeRange = import 'timeRange.libsonnet';

local queryLib = import 'query.libsonnet';
local browseLib = import 'browse.libsonnet';
local nodesChartLib = import 'nodes/chart.libsonnet';
local nodeListsDrilldownLib = import 'nodeLists/drilldown.libsonnet';
local nodeListsEntityLib = import 'nodeLists/entity.libsonnet';
local nodesListLib = import 'nodes/list.libsonnet';
local nodesLabelsLib = import 'nodes/labels.libsonnet';
local nodesValuesLib = import 'nodes/values.libsonnet';
local nodesDashboardLib = import 'nodes/dashboard.libsonnet';

local query = queryLib(time, telemetry);
local browse = browseLib(query);

{
  promql: {
    chart: {
      node: nodesChartLib(query, timeRange),
      drillDown: { nodeList: nodeListsDrilldownLib(chain, $.promql.chart.node) },
      entity: { nodeList: nodeListsEntityLib(chain, $.promql.list.node, $.promql.chart.drillDown.nodeList) },
    },
    list: { node: nodesListLib(browse) },
    labels: { node: nodesLabelsLib(browse) },
    values: { node: nodesValuesLib(browse) },
  },
  telemetry: {
    dashboard: { node: nodesDashboardLib(query, timeRange) },
  },
}
