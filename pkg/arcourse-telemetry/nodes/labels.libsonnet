local a = import '../../arcourse-ui/main.libsonnet';
local browse = import '../browse.libsonnet';

a.list.view {
  local n = self,
  datasource:: 'default',
  expr:: error 'Labels requires expr',
  link:: error 'Labels requires link',
  group:: browse.defaultGroup(n),
  data: browse.labelNames(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now'))),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
}
