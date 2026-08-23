local c = import 'components/main.libsonnet';
local html = import 'html/main.libsonnet';
local linkspecs = import 'linkspecs.libsonnet';

local collectNeighbors(obj, textPrefix='', exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if std.type(value) != 'object' then []
        else
          if std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath') then
            [{ link: value._queryPath, text: textPath }]
          else collectNeighbors(value, textPath, exclude),
    std.objectFields(obj)
  );

local neighbors(obj) =
  local links = std.get(obj, 'links', {});
  (if std.type(links) == 'object' then collectNeighbors(links) else []) +
  collectNeighbors(obj, exclude=['data', '_view', 'links']);

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: c.page { fragment:: n._view.fragment },
    html: html.manifestHtml(self.page),
  },
};

local neighborView = baseView {
  _view+:: {
    fragment: c.list { items:: neighbors($) },
  },
};

local isNode(value) =
  std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

local directNeighbors(obj, exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        if isNode(value) then [{ link: value._queryPath, text: k }] else [],
    std.objectFields(obj)
  );

local linksItems(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k) if isNode(links[k]) then [{ link: links[k]._queryPath, text: k }] else [],
    std.objectFields(links)
  );

local linksGroups(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value) }]
      else [],
    std.objectFields(links)
  );

local groupView = baseView {
  _view+:: {
    fragment: c.groupList {
      items:: directNeighbors($, exclude=['data', '_view', 'links']) + linksItems($),
      groups:: linksGroups($),
    },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.yaml { data:: $.data },
  },
};

local safeGet(obj, path) =
  std.foldl(
    function(acc, k)
      if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
    path,
    obj
  );

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
      },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment:
      local items = neighbors($);
      local listCard = if std.length(items) > 0 then [c.list { items:: items, style:: ' min-width: 8em;' }] else [];
      listCard + [c.yaml { data:: $.data }],
  },
};

local withNode = { node: self.view + linkspecs.withLinkSpecs };

{
  default: { view: neighborView } + withNode,
  list: { view: neighborView } + withNode,
  groupList: { view: groupView } + withNode,
  table: { view: tableView } + withNode,
  yaml: { view: yamlView } + withNode,
  resource: { view: resourceView } + withNode,
}
