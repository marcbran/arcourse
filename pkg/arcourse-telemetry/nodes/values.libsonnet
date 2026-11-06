local a = import '../../arcourse-ui/main.libsonnet';

function(browse)
  a.yaml.view {
    local n = self,
    datasource:: 'default',
    expr:: error 'Values requires expr',
    label:: error 'Values requires label',
    response:: browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')),
    data: browse.labelValues(n.response, n.label),
  }
