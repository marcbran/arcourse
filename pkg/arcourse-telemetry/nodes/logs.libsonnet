local ui = import '../../arcourse-ui/components/main.libsonnet';
local html = import '../../arcourse-ui/html/main.libsonnet';
local logs = import '../components/logs.libsonnet';

function(query, timeRange)
  {
    local n = self,
    datasource:: 'default',
    type:: 'logql',
    expr:: error 'Logs requires expr',
    _paramSpecs: timeRange.paramSpecs,
    _telemetryItems:: [{ type: n.type, expr: n.expr }],
    data: query(n.datasource, n._telemetryItems, n._params.from, n._params.to),
    records: std.reverse(std.sort(
      std.get(n.data.results[0], 'records', []),
      function(rec) rec.timestamp
    )),
    _view:: {
      local hasRecords = std.length(n.records) > 0,
      local nav = timeRange.element {
        from:: n._params.from,
        to:: n._params.to,
        resultTo:: if hasRecords then n.records[0].timestamp else null,
        resultFrom:: if hasRecords then n.records[std.length(n.records) - 1].timestamp else null,
      },
      fragment: [
        timeRange.script.html,
        nav.html,
        logs { records:: n.records },
        nav.html,
      ],
      page: ui.page {
        fragment:: n._view.fragment,
        breadcrumbs:: ui.breadcrumbs { pathTemplate:: std.get(n, '_pathTemplate', []), node:: n },
      },
      html: html.manifestHtml(self.page),
    },
  }
