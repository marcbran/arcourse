local list = import 'list.libsonnet';
local yaml = import 'yaml.libsonnet';

local style = |||
  .resource {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    gap: 0.25em;
  }
  .resource > .yaml {
    flex: 1 1 0;
    min-width: 0;
  }
|||;

{
  local c = self,
  data:: error 'Resource requires data',
  items:: [],
  groups:: [],
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'resource' },
      children:
        (if std.length(c.items) > 0 || std.length(c.groups) > 0 then
           [list { items:: c.items, groups:: c.groups, style:: ' min-width: 8em;' }]
         else []) + [yaml { data:: c.data }],
    },
  ],
}
