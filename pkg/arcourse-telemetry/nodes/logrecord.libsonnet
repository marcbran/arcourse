local ui = import '../../arcourse-ui/components/main.libsonnet';
local html = import '../../arcourse-ui/html/main.libsonnet';
local logs = import '../components/logs.libsonnet';

function(telemetry)
  {
    local n = self,
    data: telemetry.fetch(n.type, n.datasource, n.id),
    _view:: {
      fragment: logs { records:: [n.data.record] },
      page: ui.page {
        fragment:: n._view.fragment,
        breadcrumbs:: ui.breadcrumbs { pathTemplate:: std.get(n, '_pathTemplate', []), node:: n },
      },
      html: html.manifestHtml(self.page),
    },
  }
