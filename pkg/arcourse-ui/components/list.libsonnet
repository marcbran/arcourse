local style = |||
  @scope (.list) {
    :scope {
      font-family: monospace;
      display: inline-flex;
      flex-direction: column;
      gap: 0.25em;
    }
    a {
      color: var(--primary-color);
      border-radius: 0.5em;
    }
    a:hover {
      text-decoration: none;
    }
    a:focus {
      outline: 2px solid var(--primary-color);
      outline-offset: 2px;
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    :scope.columns {
      flex-direction: row;
      flex-wrap: wrap;
      align-items: flex-start;
    }
    .list-column {
      display: flex;
      flex-direction: column;
      gap: 0.25em;
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
          attributes: { href: item.link } + (
            if std.get(item, 'external', false)
            then { target: '_blank', rel: 'noopener noreferrer' }
            else {}
          ),
          children: [item.text],
        }],
      }
      for item in c.items
    ],
  },
};

local card = {
  local c = self,
  title:: null,
  items:: error 'Card requires items',
  lines:: std.length(c.items) + (if c.title == null then 0 else 1),
  html: {
    element: 'nav',
    attributes: { class: 'card' },
    children:
      (if c.title == null then [] else [{ element: 'strong', children: [c.title] }])
      + [itemList { items:: c.items }],
  },
};

local column = {
  local c = self,
  cards:: error 'Column requires cards',
  html: {
    element: 'div',
    attributes: { class: 'list-column' },
    children: [card.html for card in c.cards],
  },
};

local lineCount(cards) = std.foldl(function(acc, card) acc + card.lines, cards, 0);

local distribute(cards, count) =
  local target = lineCount(cards) / count;
  std.foldl(
    function(columns, card)
      local last = columns[std.length(columns) - 1];
      if std.length(last) > 0 && std.length(columns) < count && lineCount(last) + card.lines / 2 > target
      then columns + [[card]]
      else columns[:std.length(columns) - 1] + [last + [card]],
    cards,
    [[]]
  );

{
  local c = self,
  items:: error 'List requires items',
  groups:: [],
  columns:: 1,
  style:: '',
  local cards =
    (if std.length(c.items) > 0 then [card { items:: c.items }] else [])
    + [card { title:: group.title, items:: group.items } for group in c.groups],
  html: [
    { element: 'style', children: [style] },
    {
      element: 'aside',
      attributes: { class: if c.columns > 1 then 'list columns' else 'list' } + (if c.style != '' then { style: c.style } else {}),
      children:
        if c.columns > 1 then [column { cards:: cards }.html for cards in distribute(cards, c.columns)]
        else [card.html for card in cards],
    },
  ],
}
