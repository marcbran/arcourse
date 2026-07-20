local f = import 'fragments/main.libsonnet';
local html = import 'github.com/marcbran/jsonnet/plugin/html/main.libsonnet';

local pageStyle = |||
  :root { color-scheme: light dark; --primary-color: light-dark(#0451a5, #569cd6); }
  pre {
    white-space: pre-wrap;
    word-break: break-all;
  }
  a:hover {
    text-decoration: none;
  }
  table {
    border-spacing: 1.5em 0;
  }
|||;

local htmlPage(fragment) = '<!doctype html>' + html.manifestHtml({
  element: 'html',
  children: [
    { element: 'head', children: [{ element: 'style', children: [pageStyle] }] },
    { element: 'body', children: [fragment] },
  ],
});

local neighborView = {
  _view:: {
    html: htmlPage($._view.fragment),
    fragment: f.list($),
  },
};

local yamlView = {
  _view:: {
    html: htmlPage($._view.fragment),
    fragment: f.yaml($.data),
  },
};

local tableView = {
  _view:: {
    html: htmlPage($._view.fragment),
    fragment: f.table($),
  },
};

{
  default: { view: neighborView },
  list: { view: neighborView },
  table: { view: tableView },
  yaml: { view: yamlView },
  resource: self.yaml,
}
