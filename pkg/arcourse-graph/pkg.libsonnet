local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-graph',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-graph',
  path: 'arcourse/arcourse-graph',
  target: 'arcourse-graph',
}, |||
  Path-addressable node graph primitives used to compose arcourse resource explorers.

  A graph is built from a flat list of node specs (`[path, ...bodies]`), where `path`
  segments prefixed with `$` become required variables on descendant nodes. Nodes at
  the same path are layered (merged) together.
|||, {
  node: p.desc(|||
    Builds a single node at `path` from `body` (an object or array of layers).
    Adds `_evalPath` and `_queryPath` helpers plus placeholders for any `$var` segments.
  |||),
  graph: p.desc(|||
    Builds a full node tree from `nodeSpecs`, applying `defaultView` to any node that
    doesn't define its own `_view`.
  |||),
})
