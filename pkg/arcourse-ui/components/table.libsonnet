local style = |||
  @scope (.table-card) {
    :scope.card {
      padding: 0.25em;
    }
    :scope {
      display: inline-flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5em;
    }
  }
  @scope (.table) {
    :scope {
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
  @scope (.table-pagination) {
    :scope {
      display: flex;
      align-items: stretch;
      width: fit-content;
      border: 1px solid var(--border-color);
      border-radius: 0.5em;
      overflow: hidden;
      background: var(--container-low-color);
      font-family: monospace;
    }
    a, span.disabled {
      display: flex;
      align-items: center;
      justify-content: center;
      line-height: 1;
      width: 2.6rem;
      height: 2.6rem;
      font-size: 1.4em;
      border-right: 1px solid var(--border-color);
      text-decoration: none;
      color: var(--on-background-color);
    }
    a:last-child, span.disabled:last-child {
      border-right: none;
    }
    a:hover {
      background-color: var(--background-color);
    }
    span.disabled {
      opacity: 0.4;
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

local navLink = {
  local c = self,
  icon:: error 'NavLink requires icon',
  title:: error 'NavLink requires title',
  href:: null,
  html:
    if c.href == null then
      { element: 'span', attributes: { class: 'disabled', title: c.title }, children: [c.icon] }
    else
      { element: 'a', attributes: { href: c.href, title: c.title }, children: [c.icon] },
};

local paginationDirections = [
  { key: 'first', icon: '«', title: 'First page' },
  { key: 'prev', icon: '‹', title: 'Previous page' },
  { key: 'next', icon: '›', title: 'Next page' },
  { key: 'last', icon: '»', title: 'Last page' },
];

local paginationNav = {
  local c = self,
  pagination:: null,
  local links = if c.pagination == null then {} else c.pagination,
  visible:: std.length(std.objectFields(links)) > 0,
  html: {
    element: 'div',
    attributes: { class: 'table-pagination' },
    children: [
      local target = std.get(links, dir.key, null);
      (navLink {
        icon:: dir.icon,
        title:: dir.title,
        href:: if target == null then null else target._queryPath,
      }).html
      for dir in paginationDirections
    ],
  },
};

{
  local c = self,
  items:: error 'Table requires items',
  columns:: [],
  rowLink:: null,
  pagination:: null,
  local rows = if std.isArray(c.items) then c.items else [],
  local nav = paginationNav { pagination:: c.pagination },
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'card table-card' },
      children: [
        {
          element: 'table',
          attributes: { class: 'table' },
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
      ] + (if nav.visible then [nav.html] else []),
    },
  ],
}
