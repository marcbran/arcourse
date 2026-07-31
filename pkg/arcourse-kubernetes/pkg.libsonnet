local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubernetes',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-kubernetes',
  path: 'arcourse/arcourse-kubernetes',
  target: 'arcourse-kubernetes',
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
    string or returned as an AST.
  |||),
})
