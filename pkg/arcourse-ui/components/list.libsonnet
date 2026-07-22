{
  local c = self,
  items:: error 'List requires items',
  html: {
    element: 'aside',
    attributes: { style: 'font-family: monospace' },
    children: [{
      element: 'nav',
      children: [{
        element: 'ul',
        attributes: { style: 'list-style: none;' },
        children: [
          {
            element: 'li',
            children: [{
              element: 'a',
              attributes: { href: item.link, style: 'color: var(--primary-color)' },
              children: [item.text],
            }],
          }
          for item in c.items
        ],
      }],
    }],
  },
}
