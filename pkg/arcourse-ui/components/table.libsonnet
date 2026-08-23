local style = |||
  @scope (.table) {
    :scope {
      display: inline-table;
      border-collapse: separate;
      border-spacing: 0;
      font-family: monospace;
    }
    th {
      color: var(--primary-color);
      font-weight: bold;
      padding: 0.3em 0.4em;
    }
    td {
      padding: 0;
    }
    td > * {
      display: block;
      box-sizing: border-box;
      height: 100%;
      padding: 0.3em 0.4em;
    }
    td > a {
      text-decoration: none;
      color: var(--on-background-color);
    }
    tbody tr:has(a):hover {
      background-color: var(--container-low-color);
    }
    td.empty {
      text-align: center;
      opacity: 0.6;
    }
  }
|||;

local cellValue(item, col) =
  if std.objectHas(col, 'value') then col.value(item)
  else std.foldl(
    function(acc, k) if std.type(acc) == 'object' then std.get(acc, k, null) else null,
    col.path,
    item
  );

local cellText(item, col) =
  local val = cellValue(item, col);
  if val == null then '' else std.toString(val);

local rowHref(rowLink, item) =
  if rowLink == null then null
  else
    local target = rowLink(item);
    if std.type(target) == 'object' && std.objectHasAll(target, '_queryPath')
    then target._queryPath
    else null;

local cell = {
  local c = self,
  item:: error 'Cell requires item',
  col:: error 'Cell requires col',
  href:: null,
  local text = cellText(c.item, c.col),
  html:
    if c.href == null then
      { element: 'span', children: [text] }
    else
      { element: 'a', attributes: { href: c.href }, children: [text] },
};

local emptyRow = {
  local c = self,
  columnCount:: error 'EmptyRow requires columnCount',
  html: {
    element: 'tr',
    children: [{
      element: 'td',
      attributes: { class: 'empty', colspan: std.max(1, c.columnCount) },
      children: [{ element: 'span', children: ['No items'] }],
    }],
  },
};

{
  local c = self,
  items:: error 'Table requires items',
  columns:: [],
  rowLink:: null,
  local rows = if std.isArray(c.items) then c.items else [],
  html: [
    { element: 'style', children: [style] },
    {
      element: 'table',
      attributes: { class: 'table card' },
      children: [
        {
          element: 'thead',
          children: [{
            element: 'tr',
            children: [
              { element: 'th', children: [col.label] }
              for col in c.columns
            ],
          }],
        },
        {
          element: 'tbody',
          children:
            if std.length(rows) == 0 then [emptyRow { columnCount:: std.length(c.columns) }]
            else [
              local href = rowHref(c.rowLink, item);
              {
                element: 'tr',
                children: [
                  { element: 'td', children: [cell { item:: item, col:: col, href:: href }] }
                  for col in c.columns
                ],
              }
              for item in rows
            ],
        },
      ],
    },
  ],
}
