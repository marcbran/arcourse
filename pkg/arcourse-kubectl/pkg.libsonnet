local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubectl',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-kubectl',
  path: 'arcourse/arcourse-kubectl',
  target: 'arcourse-kubectl',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-kubectl', 'v0.3.0'),
    p.plugin.github('marcbran/jsonnet-plugin-jsonnet', 'v0.3.0'),
  ],
}, |||
  Generates an arcourse graph for browsing Kubernetes resources via `kubectl`.

  Discovers API resources for one or more configured contexts and generates Jsonnet
  source (via jsonnet-plugin-jsonnet) that wires up list/detail nodes per resource,
  reading data through jsonnet-plugin-kubectl.
|||, {
  graph: p.desc(|||
    Root package. `data.contexts` are the configured kubeconfig context(s) and
    `manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
    string or returned as an AST.
  |||),
})
