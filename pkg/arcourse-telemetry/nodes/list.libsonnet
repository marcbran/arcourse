local a = import '../../arcourse-ui/main.libsonnet';
local browse = import '../browse.libsonnet';

a.list.view {
  local n = self,
  datasource:: 'default',
  expr:: error 'List requires expr',
  label:: error 'List requires label',
  link:: error 'List requires link',
  group:: browse.defaultGroup(n),
  data: browse.labelValues(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
}
