local list = import 'list.libsonnet';
local yaml = import 'yaml.libsonnet';

{
  local c = self,
  data:: error 'Resource requires data',
  items:: [],
  groups:: [],
  html:
    (if std.length(c.items) > 0 || std.length(c.groups) > 0 then
       [list { items:: c.items, groups:: c.groups, style:: ' min-width: 8em;' }]
     else []) + [yaml { data:: c.data }],
}
