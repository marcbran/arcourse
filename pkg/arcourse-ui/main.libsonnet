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

local linksGroups(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value, linkStrings=true) }]
      else [],
    std.objectFields(links)
  );

local curatedLinks(obj) =
  std.set([
    item.link
    for item in linksItems(obj) + std.flatMap(function(group) group.items, linksGroups(obj))
  ]);

local neighborItems(obj) =
  local curated = curatedLinks(obj);
  [
    item
    for item in collectNeighbors(obj, '', ['data', '_view', 'links'])
    if !std.setMember(item.link, curated)
  ] + linksItems(obj);

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
      groups:: linksGroups($),
    },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.yaml { data:: $.data },
  },
};

local tableView = baseView {
  _view+:: {
    fragment:
      local table = std.get($, 'table', {});
      local at = std.get(table, 'at', ['items']);
      local items = safeGet($.data, at);
      c.table {
        items:: items,
        columns:: std.get(table, 'columns', []),
        rowLink:: linkspecs.rowLinkFor($, std.get($, 'linkSpecs', []), at),
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
        groups:: linksGroups($),
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
      groups:: linksGroups($),
    },
  },
};

local actionView = baseView {
  _view+:: {
    fragment: c.action {
      evaluationId:: std.get($, '_evaluationId', ''),
      summary:: std.get($, '_summary', ''),
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
