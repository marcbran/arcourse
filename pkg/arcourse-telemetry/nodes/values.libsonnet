local a = import '../../arcourse-ui/main.libsonnet';

function(browse)
  a.yaml.view {
    local n = self,
    datasource:: 'default',
    expr:: error 'Values requires expr',
    label:: error 'Values requires label',
    data: browse.labelValues(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
  }
