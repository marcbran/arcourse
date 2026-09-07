local chart = import 'chart.libsonnet';

local style = |||
  @scope (.dashboard) {
    :scope {
      display: flex;
      width: 100%;
      box-sizing: border-box;
      gap: 1em;
    }
    .dashboard-branch {
      display: flex;
      box-sizing: border-box;
      min-width: 0;
      min-height: 0;
      gap: 1em;
    }
    .dashboard-panel {
      display: flex;
      box-sizing: border-box;
      min-width: 0;
      min-height: 0;
    }
  }
|||;

local direction(node) = if node.type == 'row' then 'row' else 'column';

local layoutNode = {
  local c = self,
  node:: error 'LayoutNode requires node',
  path:: [],
  html::
    if c.node.type == 'panel' then
      {
        element: 'div',
        attributes: { class: 'dashboard-panel', style: 'flex: %s 1 0%%;' % [c.node.flex] },
        children: [
          chart {
            option:: c.node.chart.option,
            links:: c.node.chart.links,
            id:: 'chart-' + std.join('-', [std.toString(p) for p in c.path]),
            width:: '100%',
            height:: '100%',
          },
        ],
      }
    else
      {
        element: 'div',
        attributes: {
          class: 'dashboard-branch',
          style: 'flex: %s 1 0%%; flex-direction: %s;' % [c.node.flex, direction(c.node)],
        },
        children: [
          (layoutNode { node:: c.node.children[i], path:: c.path + [i] }).html
          for i in std.range(0, std.length(c.node.children) - 1)
        ],
      },
};

{
  local c = self,
  layout:: error 'Dashboard requires layout',
  height:: '600px',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: {
        class: 'dashboard',
        style: 'flex-direction: %s; height: %s;' % [direction(c.layout), c.height],
      },
      children: [
        (layoutNode { node:: c.layout.children[i], path:: [i] }).html
        for i in std.range(0, std.length(c.layout.children) - 1)
      ],
    },
  ],
}
