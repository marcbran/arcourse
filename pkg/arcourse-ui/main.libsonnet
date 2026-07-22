local c = import 'components/main.libsonnet';
local html = import 'github.com/marcbran/jsonnet/plugin/html/main.libsonnet';

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
    fragment: c.panel { child:: c.list { items:: neighbors($) } },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.panel { child:: c.yaml { data:: $.data } },
  },
};

local tableView = baseView {
  _view+:: {
    fragment: c.panel {
      child:: c.table {
        items:: $.data.items,
        columns:: std.get($, 'columns', []),
      },
    },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment:
      local items = neighbors($);
      if std.length(items) > 0 then
        {
          element: 'div',
          attributes: { style: 'display: inline-flex; gap: 0.25em; border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.25em;' },
          children: [
            c.panel { child:: c.list { items:: items }, style:: ' min-width: 8em;' },
            c.panel { child:: c.yaml { data:: $.data } },
          ],
        }
      else
        c.panel { child:: c.yaml { data:: $.data } },
  },
};

{
  default: { view: neighborView },
  list: { view: neighborView },
  table: { view: tableView },
  yaml: { view: yamlView },
  resource: { view: resourceView },
}
