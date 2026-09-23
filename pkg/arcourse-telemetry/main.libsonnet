local time = import 'time/main.libsonnet';
local telemetry = import 'telemetry/main.libsonnet';
local chain = import 'chain.libsonnet';
local timeRange = import 'timeRange.libsonnet';
local g = import '../arcourse-graph/main.libsonnet';

local queryLib = import 'query.libsonnet';
local browseLib = import 'browse.libsonnet';
local nodesChartLib = import 'nodes/chart.libsonnet';
local nodeListsDrilldownLib = import 'nodeLists/drilldown.libsonnet';
local nodeListsEntityLib = import 'nodeLists/entity.libsonnet';
local nodeListsEntitiesLib = import 'nodeLists/entities.libsonnet';
local nodesListLib = import 'nodes/list.libsonnet';
local nodesLabelsLib = import 'nodes/labels.libsonnet';
local nodesValuesLib = import 'nodes/values.libsonnet';
local nodesLogsLib = import 'nodes/logs.libsonnet';
local nodesLogrecordLib = import 'nodes/logrecord.libsonnet';
local nodesDashboardLib = import 'nodes/dashboard.libsonnet';

local query = queryLib(time, telemetry);
local browse = browseLib(query);
local chartLib = nodesChartLib(query, timeRange);
local logsLib = nodesLogsLib(query, timeRange);
local logrecordLib = nodesLogrecordLib(telemetry);

{
  promql: {
    chart: { base: chartLib.base },
    line: { chart: $.promql.chart.base + chartLib.line },
    stateTimeline: { chart: $.promql.chart.base + chartLib.stateTimeline },
    drilldown: { nodeList: nodeListsDrilldownLib(chain) },
    entity: { nodeList: nodeListsEntityLib(chain, $.promql.list.node, $.promql.drilldown.nodeList, $.logs.node) },
    entities: { nodeList: nodeListsEntitiesLib($.promql.entity.nodeList) },
    list: { node: nodesListLib(browse) },
    labels: { node: nodesLabelsLib(browse) },
    values: { node: nodesValuesLib(browse) },
  },
  logs: {
    node: logsLib { record:: $.logs.record },
    record: {
      recordPath:: ['telemetry', 'logrecord', '$type', '$datasource', '$id'],
      node:: logrecordLib,
      nodeList: [[self.recordPath, self.node]],
      graphNode: g.node(self.recordPath, self.node),
    },
  },
  telemetry: {
    dashboard: { node: nodesDashboardLib(query, timeRange) },
  },
}
