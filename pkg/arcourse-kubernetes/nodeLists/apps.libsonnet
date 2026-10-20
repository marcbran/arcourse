local a = import '../../arcourse-ui/main.libsonnet';
local coreLib = import 'core.libsonnet';
local kubernetes = import '../kubernetes/main.libsonnet';
local time = import '../time/main.libsonnet';
local root = import 'root';

local podSelectorTable = a.table.node + coreLib.podTableNode {
  allPods:: kubernetes.get($.context, std.format('/api/v1/namespaces/%s/pods', [std.toString($.namespace)])).items,
  data:: {
    items: [
      p
      for p in $.allPods
      if std.all([std.objectHas(p.metadata.labels, k) && p.metadata.labels[k] == $.selector[k] for k in std.objectFields($.selector)])
    ],
  },
  linkSpecs:: [
    {
      at: ['items'],
      keys: [{ path: ['metadata', 'name'] }],
      value: [{ const: 'kubernetes' }, { origin: 'context' }, { origin: 'namespace' }, { param: 'pod', path: ['metadata', 'name'] }],
    },
  ],
};

local restartNode = a.action.node {
  resource:: error 'restartNode requires a resource',
  resourceName:: error 'restartNode requires a resourceName',
  redirectTo:: error 'restartNode requires a redirectTo',
  _summary: 'Restart %s/%s in %s' % [$.resource, $.resourceName, $.namespace],
  _action: {
    plugin: 'kubernetes',
    name: 'patch',
    data: {
      ctx: $.context,
      path: std.format('/apis/apps/v1/namespaces/%s/%s/%s', [std.toString($.namespace), $.resource, $.resourceName]),
      patch: {
        spec: {
          template: {
            metadata: {
              annotations: {
                'kubectl.kubernetes.io/restartedAt': time.format(time.now(), '2006-01-02T15:04:05Z07:00'),
              },
            },
          },
        },
      },
    },
    redirect: $.redirectTo,
  },
};

local nodeList = [
  [['kubernetes', '$context', '$namespace', 'apps', '$deployment', 'pods'], podSelectorTable {
    selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/deployments/%s', [std.toString($.namespace), std.toString($.deployment)])).spec.selector.matchLabels,
  }],
  [['kubernetes', '$context', '$namespace', 'apps', '$statefulset', 'pods'], podSelectorTable {
    selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/statefulsets/%s', [std.toString($.namespace), std.toString($.statefulset)])).spec.selector.matchLabels,
  }],
  [['kubernetes', '$context', '$namespace', 'apps', '$daemonset', 'pods'], podSelectorTable {
    selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/daemonsets/%s', [std.toString($.namespace), std.toString($.daemonset)])).spec.selector.matchLabels,
  }],
  [['kubernetes', '$context', '$namespace', 'apps', '$deployment', 'action', 'restart'], restartNode {
    resource:: 'deployments',
    resourceName:: $.deployment,
    redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.deployment($.deployment).pods,
  }],
  [['kubernetes', '$context', '$namespace', 'apps', '$statefulset', 'action', 'restart'], restartNode {
    resource:: 'statefulsets',
    resourceName:: $.statefulset,
    redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.statefulset($.statefulset).pods,
  }],
  [['kubernetes', '$context', '$namespace', 'apps', '$daemonset', 'action', 'restart'], restartNode {
    resource:: 'daemonsets',
    resourceName:: $.daemonset,
    redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.daemonset($.daemonset).pods,
  }],
];

{
  nodeList: nodeList,
}
