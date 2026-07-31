local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-openapi',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-openapi',
  path: 'arcourse/arcourse-openapi',
  target: 'arcourse-openapi',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-openapi', 'v0.3.1'),
    p.plugin.github('marcbran/jsonnet-plugin-jsonnet', 'v0.3.0'),
  ],
}, |||
  Generates an arcourse graph for browsing any OpenAPI-described service.

  Resolves an OpenAPI spec (via jsonnet-plugin-openapi) into a nested operation tree
  and generates Jsonnet source (via jsonnet-plugin-jsonnet) that wires up nodes for
  each resource-shaped operation, optionally cross-linked via `links` and rendered
  with custom `columns`.
|||, {
  graph: p.desc(|||
    Root package. `service` names the generated context node, `spec` is the OpenAPI
    document, `links`/`columns` customize cross-references and table columns, and
    `contextParams` lists extra parameters threaded through generated requests.
    `manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
    string or returned as an AST.
  |||),
})
