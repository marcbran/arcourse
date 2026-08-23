local style = |||
  @scope (.list) {
    :scope {
      font-family: monospace;
    }
    a {
      color: var(--primary-color);
    }
    a:hover {
      text-decoration: none;
    }
    ul {
      list-style: none;
    }
  }
|||;

{
  local c = self,
  items:: error 'List requires items',
  style:: '',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'aside',
      attributes: { class: 'list card' } + (if c.style != '' then { style: c.style } else {}),
      children: [{
        element: 'nav',
        children: [{
          element: 'ul',
          children: [
            {
              element: 'li',
              children: [{
                element: 'a',
                attributes: { href: item.link },
                children: [item.text],
              }],
            }
            for item in c.items
          ],
        }],
      }],
    },
  ],
}
