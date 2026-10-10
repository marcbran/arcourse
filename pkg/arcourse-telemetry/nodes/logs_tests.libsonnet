local g = import '../../arcourse-graph/main.libsonnet';
local timeRange = import '../timeRange.libsonnet';
local nodesLogsLib = import 'logs.libsonnet';

local records = [{
  id: 'r1',
  timestamp: 1,
  body: 'line',
  fields: { namespace: 'ns', k8s: { pod: 'p1', labels: { app: 'web' } }, tags: ['t1'], empty: {} },
}];

local query(datasource, items, from, to) = { results: [{ records: records }] };

local logsNode(columns, params, body={}) =
  g.node(['telemetry', 'logs'], nodesLogsLib(query, timeRange) { expr:: 'x', columns:: columns } + body)
  + { _params: params };

local view(node) = node._view.fragment[2];

{
  output(input):: input(),
  tests: [
    {
      name: 'logs columns default to the configured columns with plain strings as single-segment paths',
      input:: function()
        logsNode(['namespace', ['k8s', 'pod']], {})._paramSpecs[2].default,
      expected: [['namespace'], ['k8s', 'pod']],
    },
    {
      name: 'logs column links are disabled by default',
      input:: function()
        view(logsNode(['namespace'], { from: 'now-1h', to: 'now', columns: [['namespace']] })).embeddedLinks,
      expected: [],
    },
    {
      name: 'logs embedded links add the clicked leaf path to the current columns and keep other params',
      input:: function()
        local node = logsNode(['namespace'], { from: 'now-6h', to: 'now', columns: [['namespace']] }, { columnLinks:: true });
        view(node).embeddedLinks[0].fields.k8s.labels.app.key._queryPath,
      expected: '/root/telemetry/logs?columns=%5B%5B%22namespace%22%5D%2C%5B%22k8s%22%2C%22labels%22%2C%22app%22%5D%5D&from=now-6h',
    },
    {
      name: 'logs embedded links skip existing columns, array elements and empty containers',
      input:: function()
        local node = logsNode(['namespace'], { from: 'now-1h', to: 'now', columns: [['namespace']] }, { columnLinks:: true });
        local fields = view(node).embeddedLinks[0].fields;
        { namespace: fields.namespace, tags: fields.tags, empty: fields.empty },
      expected: { namespace: null, tags: [null], empty: null },
    },
    {
      name: 'logs header joins column path segments and cells resolve paths into nested fields',
      input:: function()
        local node = logsNode([], { from: 'now-1h', to: 'now', columns: [['namespace'], ['k8s', 'pod'], ['missing']] });
        local container = view(node).html[1];
        local row = container.children[1].html.children[0];
        {
          header: [cell.children[0] for cell in container.children[0].children],
          cells: [row.children[i].children[0] for i in std.range(1, std.length(row.children) - 1)],
        },
      expected: { header: ['time', 'namespace', 'k8s.pod', 'missing'], cells: ['ns', 'p1', ''] },
    },
  ],
}
