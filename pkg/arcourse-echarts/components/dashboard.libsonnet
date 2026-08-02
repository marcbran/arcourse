local chart = import 'chart.libsonnet';

local flexStyle(node) =
  'flex: %s 1 0%%; min-width: 0; min-height: 0; box-sizing: border-box;' % [node.flex];

local direction(node) = if node.type == 'row' then 'row' else 'column';

local render(node, path) =
  if node.type == 'panel' then
    {
      element: 'div',
      attributes: { style: flexStyle(node) + ' display: flex;' },
      children: [
        chart {
          option:: node.chart,
          id:: 'chart-' + std.join('-', [std.toString(p) for p in path]),
          width:: '100%',
          height:: '100%',
        },
      ],
    }
  else
    {
      element: 'div',
      attributes: { style: flexStyle(node) + ' display: flex; flex-direction: %s; gap: 1em;' % [direction(node)] },
      children: [
        render(node.children[i], path + [i])
        for i in std.range(0, std.length(node.children) - 1)
      ],
    };

{
  local c = self,
  layout:: error 'Dashboard requires layout',
  height:: '600px',
  html: {
    element: 'div',
    attributes: {
      style: 'display: flex; flex-direction: %s; height: %s; width: 100%%; box-sizing: border-box; gap: 1em;' % [
        direction(c.layout),
        c.height,
      ],
    },
    children: [
      render(c.layout.children[i], [i])
      for i in std.range(0, std.length(c.layout.children) - 1)
    ],
  },
}
