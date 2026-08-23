local style = |||
  @scope (.group-list) {
    :scope {
      font-family: monospace;
      display: inline-flex;
      flex-direction: column;
      gap: 0.25em;
    }
    a {
      color: var(--primary-color);
    }
    a:hover {
      text-decoration: none;
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
  }
|||;

local itemList = {
  local c = self,
  items:: error 'ItemList requires items',
  html: {
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
  },
};

{
  local c = self,
  items:: error 'GroupList requires items',
  groups:: [],
  html: [
    { element: 'style', children: [style] },
    {
      element: 'aside',
      attributes: { class: 'group-list' },
      children:
        (if std.length(c.items) > 0 then [{
           element: 'nav',
           attributes: { class: 'card' },
           children: [itemList { items:: c.items }],
         }] else []) + [
          {
            element: 'nav',
            attributes: { class: 'card' },
            children: [
              { element: 'strong', children: [group.title] },
              itemList { items:: group.items },
            ],
          }
          for group in c.groups
        ],
    },
  ],
}
