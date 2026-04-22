local f = import 'fragments/main.libsonnet';
local h = import 'html/main.libsonnet';

local htmlPage(fragment) = h.manifestPage(h.html([
  h.head([
    h.style(|||
      :root { color-scheme: light dark; --primary-color: light-dark(#0451a5, #569cd6); }
      pre {
        white-space: pre-wrap;
        word-break: break-all;
      }
    |||),
  ]),
  h.body([fragment]),
]));

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

{
  default: { view: neighborView },
  list: { view: neighborView },
  yaml: { view: yamlView },
  resource: self.yaml,
}
