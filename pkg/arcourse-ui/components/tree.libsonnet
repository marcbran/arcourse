local style = |||
  @scope (.tree) {
    :scope {
      font-family: monospace;
      display: block;
      overflow-x: auto;
      line-height: 1.3;
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    li {
      white-space: pre;
    }
    a {
      color: var(--primary-color);
    }
    a:hover {
      text-decoration: none;
    }
    .prefix {
      opacity: 0.4;
      user-select: none;
    }
    .detail {
      opacity: 0.55;
      margin-left: 0.75em;
      font-size: 0.85em;
    }
  }
|||;

local link = {
  local c = self,
  node:: error 'Link requires a node',
  html: {
    element: 'a',
    attributes: { href: c.node.link },
    children: [c.node.text],
  },
};

local rowsOf(nodes, indent, root) = std.flatMap(
  function(i)
    local node = nodes[i];
    local last = i == std.length(nodes) - 1;
    [{
      node: node,
      prefix: if root then '' else indent + (if last then '╰─ ' else '├─ '),
    }] + rowsOf(
      std.get(node, 'children', []),
      if root then '' else indent + (if last then '   ' else '│  '),
      false,
    ),
  std.range(0, std.length(nodes) - 1)
);

local row = {
  local c = self,
  prefix:: error 'Row requires a prefix',
  item:: error 'Row requires an item',
  html: {
    element: 'li',
    children: [
      { element: 'span', attributes: { class: 'prefix' }, children: [c.prefix] },
      c.item,
    ],
  },
};

local rowList = {
  local c = self,
  rows:: error 'RowList requires rows',
  item:: error 'RowList requires an item',
  html: {
    element: 'ul',
    children: [
      row { prefix:: r.prefix, item:: c.item { node:: r.node } }
      for r in c.rows
    ],
  },
};

{
  local c = self,
  nodes:: error 'Tree requires nodes',
  item:: link,
  html: [
    { element: 'style', children: [style] },
    {
      element: 'section',
      attributes: { class: 'tree card' },
      children: [rowList { rows:: rowsOf(c.nodes, '', true), item:: c.item }],
    },
  ],
}
