local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-telemetry-kubernetes',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-telemetry-kubernetes',
  path: 'arcourse/arcourse-telemetry-kubernetes',
  target: 'arcourse-telemetry-kubernetes',
  external: ['root'],
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-time', 'v0.0.0'),
    p.plugin.github('marcbran/jsonnet-plugin-telemetry', 'v0.0.0'),
    p.plugin.github('marcbran/jsonnet-plugin-html', 'v0.0.0'),
  ],
}, |||
  Ready-made Kubernetes telemetry entities for arcourse-telemetry, mounted under
  `telemetry/kubernetes`. Each entity browses a dimension (`context`, `namespace`,
  `pod`, `container`, `pvc`, `deployment`, `node`) via kube-state-metrics and
  cAdvisor queries, with drilldown charts and cross-links to the matching
  `arcourse-kubernetes` resource nodes (and back).

  Assumes a `cluster` label identifies the context and that the resource tree is
  mounted at `root.kubernetes`. Each entity is exposed as an overridable field;
  `nodeList` materializes them all through `arcourse-telemetry`'s `entities.nodeList`.
|||, {
  context: p.desc('Entity spec for the cluster/context dimension.'),
  namespace: p.desc('Entity spec for the namespace dimension.'),
  pod: p.desc('Entity spec for the pod dimension, with a pod-phase state timeline drilldown.'),
  container: p.desc('Entity spec for the container dimension, with restarts/cpu/memory drilldowns.'),
  pvc: p.desc('Entity spec for the persistent volume claim dimension, with a usage drilldown.'),
  deployment: p.desc('Entity spec for the deployment dimension, with an availability drilldown.'),
  node: p.desc('Entity spec for the node dimension, with a conditions drilldown.'),
  nodeList: p.desc('All entity specs materialized through `entities.nodeList`.'),
})
