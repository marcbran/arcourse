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
  if link != null then ['a', { href: link._queryPath, style: 'color: var(--primary-color)' }, str] else str;

function(obj)
  local items = obj.data.items;
  local columns = std.get(obj, 'columns', []);
  [
    'table',
    { style: 'font-family: monospace' },
    [
      'thead',
      ['tr'] + [['th', { style: 'color: var(--primary-color); font-weight: bold' }, col.label] for col in columns],
    ],
    ['tbody'] + [
      ['tr'] + [['td', cellContent(item, col)] for col in columns]
      for item in items
    ],
  ]
