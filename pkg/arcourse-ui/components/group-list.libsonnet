local groupBorder = 'border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.75em 1em;';

local itemList(items) = {
  element: 'ul',
  attributes: { style: 'list-style: none; margin: 0; padding: 0;' },
  children: [
    {
      element: 'li',
      children: [{
        element: 'a',
        attributes: { href: item.link, style: 'color: var(--primary-color)' },
        children: [item.text],
      }],
    }
    for item in items
  ],
};

{
  local c = self,
  items:: error 'GroupList requires items',
  groups:: [],
  html: {
    element: 'aside',
    attributes: { style: 'font-family: monospace; display: inline-flex; flex-direction: column; gap: 0.25em;' },
    children:
      (if std.length(c.items) > 0 then [{
         element: 'nav',
         attributes: { style: groupBorder },
         children: [itemList(c.items)],
       }] else []) + [
        {
          element: 'nav',
          attributes: { style: groupBorder },
          children: [
            { element: 'strong', children: [group.title] },
            itemList(group.items),
          ],
        }
        for group in c.groups
      ],
  },
}
