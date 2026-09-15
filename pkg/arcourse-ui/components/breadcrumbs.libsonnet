local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varName(seg) = std.substr(seg, 1, std.length(seg) - 1);

local style = |||
  @scope (.breadcrumbs) {
    :scope {
      font-family: monospace;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 0.4em;
      width: fit-content;
      border: 1px solid var(--border-color);
      border-radius: 0.5em;
      padding: 0.5em 0.75em;
    }
    a {
      color: var(--primary-color);
      text-decoration: none;
      border-radius: 0.5em;
    }
    a:hover {
      text-decoration: underline;
    }
    a:focus {
      outline: 2px solid var(--primary-color);
      outline-offset: 2px;
    }
    .key {
      opacity: 0.55;
    }
    .sep {
      opacity: 0.4;
    }
    .current {
      color: var(--on-background-color);
    }
  }
|||;

local crumbInner = {
  local c = self,
  name:: null,
  value:: error 'crumbInner requires value',
  html:
    if c.name == null then [c.value]
    else [{ element: 'span', attributes: { class: 'key' }, children: [c.name + '/'] }, c.value],
};

{
  local c = self,
  pathTemplate:: [],
  node:: {},
  local crumbs =
    std.foldl(
      function(acc, seg)
        local entry =
          if isVar(seg) then
            local v = varName(seg);
            local val = std.toString(std.get(c.node, v, ''));
            { url: acc.url + '/' + v + '/' + val, name: v, value: val }
          else
            { url: acc.url + '/' + seg, name: null, value: seg };
        {
          url: entry.url,
          crumbs: acc.crumbs + [{ name: entry.name, value: entry.value, queryPath: entry.url }],
        },
      c.pathTemplate,
      { url: '/root', crumbs: [{ name: null, value: 'root', queryPath: '/root' }] }
    ).crumbs,
  html:
    if std.length(c.pathTemplate) == 0 then []
    else [
      { element: 'style', children: [style] },
      {
        element: 'nav',
        attributes: { class: 'breadcrumbs' },
        children: std.flattenArrays([
          (if i > 0 then [{ element: 'span', attributes: { class: 'sep' }, children: ['›'] }] else []) +
          [
            if i == std.length(crumbs) - 1
            then { element: 'span', attributes: { class: 'current' }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] }
            else { element: 'a', attributes: { href: crumbs[i].queryPath }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] },
          ]
          for i in std.range(0, std.length(crumbs) - 1)
        ]),
      },
    ],
}
