local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-ui',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-ui',
  path: 'arcourse/arcourse-ui',
  target: 'arcourse-ui',
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-html', 'v0.0.0'),
  ],
}, |||
  Shared views for rendering arcourse graph nodes as HTML, built on top of
  jsonnet-plugin-html and arcourse-ui's component library.

  Each entry renders a node's `data` and its neighboring links (`_view.fragment`),
  and wraps the result in a full page (`_view.html`).
|||, {
  default: p.desc('Same as `list`. Fallback view.'),
  list: p.desc('Renders the node\'s neighboring links as a list, grouping any nested (two-level) links under a titled section.'),
  table: p.desc('Renders `data` items (at `table.at`, default `[\'items\']`) as a table with `table.columns`, each row linking to its own item if `linkSpecs` resolves one.'),
  yaml: p.desc('Renders `data` as YAML.'),
  resource: p.desc('Renders `data` as YAML alongside its neighboring links, if any, grouping any nested (two-level) links under a titled section like `list` does.'),
})
