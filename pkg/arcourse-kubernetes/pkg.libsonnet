local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubernetes',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-kubernetes',
  path: 'arcourse/arcourse-kubernetes',
  target: 'arcourse-kubernetes',
  external: ['root'],
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-kubernetes', 'v0.1.0'),
    p.plugin.github('marcbran/jsonnet-plugin-jsonnet', 'v0.3.0'),
  ],
}, |||
  Generates an arcourse graph for browsing Kubernetes resources via the raw REST API.

  Discovers API groups/resources for one or more configured contexts and generates
  Jsonnet source (via jsonnet-plugin-jsonnet) that wires up list/detail nodes per
  resource, reading data through jsonnet-plugin-kubernetes. Supports custom columns
  and links, either explicit or derived from an OpenAPI discovery document.
|||, {
  graph: p.desc(|||
    Root package. `contexts` are the configured kubeconfig context(s), `columns` and
    `links` (both keyed by group version) override the defaults per resource, and
    `manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
    string or returned as an AST. `groupNodes` (default `true`) generates an empty node
    per API group under the context and namespace; with `false` the group segment is a
    plain object, so the context and namespace views link each group's resources
    directly, ordered as groups without dots, then `*.k8s.io` groups, then the rest,
    each as a domain tree so a subdomain follows its parent domain. `listColumns` (default `4`) is the number of columns the context node and
    the namespace detail node lay out their links in; the namespace detail node also
    shows its YAML above the links.
  |||),
  core: p.desc(|||
    Hand-written core layers on top of the generated graph. `nodeList` adds the pod
    table layer to both generated pod lists; `podTableNode` is that layer: kubectl-style
    pod columns including computed Ready and Restarts.
  |||),
  apps: p.desc(|||
    `nodeList` adds pod tables for deployments, statefulsets and daemonsets (selected
    by their label selector) and restart actions for each of them.
  |||),
  'networking.k8s.io': p.desc(|||
    `nodeList` adds an external https link per ingress rule host.
  |||),
})
