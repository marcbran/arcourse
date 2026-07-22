local cellValue(item, col) =
  if std.objectHas(col, 'value') then col.value(item)
  else std.foldl(
    function(acc, k) if std.type(acc) == 'object' then std.get(acc, k, null) else null,
    col.path,
    item
  );

local cellContent(item, col) =
  local val = cellValue(item, col);
  local str = if val == null then '' else std.toString(val);
  local link = if std.objectHas(col, 'link') then col.link(item) else null;
  if link != null then
    { element: 'a', attributes: { href: link._queryPath, style: 'color: var(--primary-color)' }, children: [str] }
  else
    str;

{
  local c = self,
  items:: error 'Table requires items',
  columns:: [],
  html: {
    element: 'table',
    attributes: { style: 'font-family: monospace' },
    children: [
      {
        element: 'thead',
        children: [{
          element: 'tr',
          children: [
            {
              element: 'th',
              attributes: { style: 'color: var(--primary-color); font-weight: bold' },
              children: [col.label],
            }
            for col in c.columns
          ],
        }],
      },
      {
        element: 'tbody',
        children: [
          {
            element: 'tr',
            children: [{ element: 'td', children: [cellContent(item, col)] } for col in c.columns],
          }
          for item in c.items
        ],
      },
    ],
  },
}
