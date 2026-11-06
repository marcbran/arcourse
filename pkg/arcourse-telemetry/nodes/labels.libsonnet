local a = import '../../arcourse-ui/main.libsonnet';

function(browse)
  a.list.view {
    local n = self,
    datasource:: 'default',
    expr:: error 'Labels requires expr',
    link:: error 'Labels requires link',
    group:: browse.defaultGroup(n),
    response:: browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')),
    data: browse.labelNames(n.response),
    links: { [n.group]: { [name]: n.link(name) for name in n.data } },
  }
