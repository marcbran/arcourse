local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubernetes',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-kubernetes',
  path: 'arcourse/arcourse-kubernetes',
  target: 'arcourse-kubernetes',
  external: ['root'],
  plugins: [
    p.plugin.github('marcbran/jsonnet-plugin-kubernetes', 'v0.9.0'),
    p.plugin.github('marcbran/jsonnet-plugin-jsonnet', 'v0.4.0'),
    p.plugin.github('marcbran/jsonnet-plugin-time', 'v0.3.1'),
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
    string or returned as an AST. Each API group is shown on the context and namespace
    views as a card linking its resources directly. Groups are ordered as groups without
    dots, then the rest as a domain tree so a subdomain follows its parent domain. `favoriteGroups` (default `[]`) is a list of domain
    patterns shown first: a pattern matches the group itself and its subdomains, `*.domain`
    matches only the subdomains and `*` matches every group; each group ranks at the
    position of its most specific matching favorite. `collapsedGroups`
    (default `[]`) is a list of domain patterns whose groups get
    an empty node instead of a card; their links are listed in one card titled
    `remainingGroupsTitle` (default `'remaining groups'`) after the other cards. When a
    group matches both lists, the more specific pattern wins and a tie goes to the favorite.
    `hiddenGroups` (default `[]`) takes the same patterns for groups left out of the cards
    and of `remainingGroupsTitle` entirely; their nodes still exist. Across all three lists
    the most specific pattern wins, a tie going to favorite, then collapsed, then hidden.
    `hiddenResources` (default `{}`) maps an API group (`''` for core) to resource names
    left out of its card and, for a collapsed group, out of its node's links; the
    resources' nodes still exist.
    `listColumns` (default `4`) is the number of columns the context node and
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
