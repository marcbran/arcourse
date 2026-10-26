local linkspecs = import '../arcourse-graph/linkspecs.libsonnet';
local c = import 'components/main.libsonnet';
local html = import 'html/main.libsonnet';

local isNode(value) =
  std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

local collectNeighbors(obj, textPrefix='', exclude=[], linkStrings=false) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if isNode(value) then [{ link: value._queryPath, text: textPath }]
        else if std.type(value) == 'object' then collectNeighbors(value, textPath, exclude, linkStrings)
        else if linkStrings && std.type(value) == 'string' then [{ link: value, text: textPath, external: true }]
        else [],
    std.objectFields(obj)
  );

local linksItems(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if isNode(value) then [{ link: value._queryPath, text: k }]
      else if std.type(value) == 'string' then [{ link: value, text: k, external: true }]
      else [],
    std.objectFields(links)
  );

local filterItems(obj, title, items) =
  local hidden = std.get(std.get(std.get(obj, 'list', {}), 'hiddenItems', {}), title, []);
  [item for item in items if !std.member(hidden, item.text)];

local linksGroups(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: filterItems(obj, k, collectNeighbors(value, linkStrings=true)) }]
      else [],
    std.objectFields(links)
  );

local curatedLinks(obj) =
  std.set([
    item.link
    for item in linksItems(obj) + std.flatMap(function(group) group.items, linksGroups(obj))
  ]);

local neighborKeys(obj) = [
  k
  for k in std.objectFields(obj)
  if !std.member(['data', '_view', 'links'], k) && std.substr(k, 0, 1) != '_' && std.type(obj[k]) == 'object'
];

local nodeGroupsSpec(obj) = std.get(std.get(obj, 'list', {}), 'nodeGroups', {});

local nodeGroupedKeys(obj) =
  local spec = nodeGroupsSpec(obj);
  std.set(std.flattenArrays([spec[title] for title in std.objectFields(spec)]));

local neighborItems(obj) =
  local curated = curatedLinks(obj);
  local grouped = nodeGroupedKeys(obj);
  filterItems(obj, '', [
    { link: obj[k]._queryPath, text: k }
    for k in neighborKeys(obj)
    if isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated) && !std.setMember(k, grouped)
  ] + linksItems(obj));

local nodeGroups(obj) =
  local spec = nodeGroupsSpec(obj);
  local curated = curatedLinks(obj);
  [
    group
    for title in std.objectFields(spec)
    for group in [{
      title: title,
      items: filterItems(obj, title, [
        { link: obj[k]._queryPath, text: k }
        for k in spec[title]
        if std.objectHas(obj, k) && isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated)
      ]),
    }]
    if std.length(group.items) > 0
  ];

local childGroups(obj) =
  local curated = curatedLinks(obj);
  [
    group
    for k in neighborKeys(obj)
    if !isNode(obj[k])
    for group in [{ title: k, items: filterItems(obj, k, [item for item in collectNeighbors(obj[k]) if !std.setMember(item.link, curated)]) }]
    if std.length(group.items) > 0
  ];

local orderGroups(groups, order) =
  local rank = { [order[i]]: i for i in std.range(0, std.length(order) - 1) };
  local keyed = [
    { group: groups[i], key: std.get(rank, groups[i].title, std.length(order) + i) }
    for i in std.range(0, std.length(groups) - 1)
  ];
  [entry.group for entry in std.sort(keyed, function(entry) entry.key)];

local neighborGroups(obj) =
  local list = std.get(obj, 'list', {});
  local hidden = std.get(list, 'hiddenGroups', []);
  [
    group
    for group in orderGroups(linksGroups(obj) + childGroups(obj) + nodeGroups(obj), std.get(list, 'groupOrder', []))
    if !std.member(hidden, group.title)
  ];

local safeGet(obj, path) =
  std.foldl(
    function(acc, k)
      if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
    path,
    obj
  );

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: c.page {
      fragment:: n._view.fragment,
      breadcrumbs:: c.breadcrumbs { pathTemplate:: std.get($, '_pathTemplate', []), node:: $ },
    },
    html: html.manifestHtml(self.page),
  },
};

local listView = baseView {
  _view+:: {
    fragment: c.list {
      items:: neighborItems($),
      groups:: neighborGroups($),
      columns:: std.get(std.get($, 'list', {}), 'columns', 1),
    },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.yaml { data:: $.data },
  },
};

local columnValue(item, col) =
  if std.objectHasAll(col, 'value') then col.value(item) else safeGet(item, col.path);

local isAlphanumeric(ch) =
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9');

local labelWords(label) = [
  word
  for word in std.split(std.join('', [if isAlphanumeric(ch) then ch else ' ' for ch in std.stringChars(label)]), ' ')
  if word != ''
];

local lowerCamelCase(label) =
  local parts = labelWords(std.toString(label));
  if std.length(parts) == 0 then ''
  else std.asciiLower(parts[0]) + std.join('', [std.asciiUpper(part[0]) + part[1:] for part in parts[1:]]);

local columnKey(col) = std.get(col, 'key', lowerCamelCase(col.label));

local projectItem(item, columns) = {
  [col.key]: value
  for col in columns
  for value in [columnValue(item, col)]
  if value != null
};

local tableView = baseView {
  data:: error 'table requires data',
  local table = std.get($, 'table', {}),
  local at = std.get(table, 'at', ['items']),
  local columns = [col { key: columnKey(col) } for col in std.get(table, 'columns', [])],
  local found = safeGet($.data, at),
  local dataItems = if std.isArray(found) then found else [],
  items: [projectItem(item, columns) for item in dataItems],
  _view+:: {
    fragment:
      local rowLink = linkspecs.rowLinkFor($, std.get($, 'linkSpecs', []), at);
      c.table {
        items:: $.items,
        columns:: columns,
        rowLinks:: if rowLink == null then [] else [rowLink(item) for item in dataItems],
        pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
      },
  },
};

local treeView = baseView {
  _view+:: {
    fragment:
      local tree = std.get($, 'tree', {});
      c.resource {
        items:: neighborItems($),
        groups:: neighborGroups($),
        columns:: std.get(std.get($, 'list', {}), 'columns', 1),
        content:: c.tree {
          nodes:: std.get(tree, 'nodes', []),
          item:: std.get(tree, 'item', super.item),
        },
      },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment: c.resource {
      data:: $.data,
      items:: neighborItems($),
      groups:: neighborGroups($),
      columns:: std.get(std.get($, 'list', {}), 'columns', 1),
      stacked:: std.get(std.get($, 'resource', {}), 'stacked', false),
    },
  },
};

local actionView = baseView {
  _view+:: {
    fragment: c.action {
      evaluationId:: std.get($, '_evaluationId', ''),
      summary:: std.get($, '_summary', ''),
      paramSpecs:: std.get($, '_paramSpecs', []),
      params:: std.get($, '_params', {}),
      initialValues:: std.get($, '_paramInitialValues', {}),
      action:: std.get($, '_action', null),
    },
  },
};

local withNode = { node: self.view + linkspecs.withLinkSpecs };

{
  default: { view: listView } + withNode,
  list: { view: listView } + withNode,
  table: { view: tableView } + withNode,
  tree: { view: treeView } + withNode,
  yaml: { view: yamlView } + withNode,
  resource: { view: resourceView } + withNode,
  action: { view: actionView } + withNode,
}
