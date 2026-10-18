local list = import 'list.libsonnet';
local yaml = import 'yaml.libsonnet';

local style = |||
  .resource {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    gap: 0.25em;
  }
  .resource > .yaml,
  .resource > .tree {
    flex: 1 1 0;
    min-width: 0;
  }
  .resource.stacked {
    flex-direction: column;
    flex-wrap: nowrap;
  }
  .resource.stacked > .yaml,
  .resource.stacked > .tree {
    flex: none;
  }
|||;

{
  local c = self,
  data:: error 'Resource requires data',
  content:: yaml { data:: c.data },
  items:: [],
  groups:: [],
  columns:: 1,
  stacked:: false,
  local links =
    if std.length(c.items) > 0 || std.length(c.groups) > 0 then
      [list { items:: c.items, groups:: c.groups, columns:: c.columns, style:: ' min-width: 8em;' }]
    else [],
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: if c.stacked then 'resource stacked' else 'resource' },
      children: if c.stacked then [c.content] + links else links + [c.content],
    },
  ],
}
