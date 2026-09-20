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
  `arcourse-kubernetes` resource nodes (and back). The `context`, `namespace`,
  `pod`, and `container` entities also expose a `logs` view.

  This is an opinionated, backend-coupled convenience layer: metric drilldowns
  assume Prometheus/PromQL (kube-state-metrics + cAdvisor), and the `logs`
  selectors assume Loki/LogQL, with `cluster`/`namespace`/`container` as indexed
  labels and `pod` as structured metadata (`| pod="..."`). Each entity's queries
  are overridable fields, so a different metrics or logs backend can be swapped
  in per entity.

  Assumes a `cluster` label identifies the context and that the resource tree is
  mounted at `root.kubernetes`. Each entity is exposed as an overridable field;
  `nodeList` materializes them all through `arcourse-telemetry`'s `entities.nodeList`.
|||, {
  context: p.desc('Entity spec for the cluster/context dimension, with a logs view.'),
  namespace: p.desc('Entity spec for the namespace dimension, with a logs view.'),
  pod: p.desc('Entity spec for the pod dimension, with a pod-phase state timeline drilldown and a logs view.'),
  container: p.desc('Entity spec for the container dimension, with restarts/cpu/memory drilldowns and a logs view.'),
  pvc: p.desc('Entity spec for the persistent volume claim dimension, with a usage drilldown.'),
  deployment: p.desc('Entity spec for the deployment dimension, with an availability drilldown.'),
  node: p.desc('Entity spec for the node dimension, with a conditions drilldown.'),
  nodeList: p.desc('All entity specs materialized through `entities.nodeList`.'),
})
