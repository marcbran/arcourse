local ui = import '../../arcourse-ui/components/main.libsonnet';
local html = import '../../arcourse-ui/html/main.libsonnet';
local logs = import '../components/logs.libsonnet';

function(query, timeRange, record=null)
  {
    local n = self,
    datasource:: 'default',
    type:: 'logql',
    expr:: error 'Logs requires expr',
    columns:: [],
    _paramSpecs: timeRange.paramSpecs,
    _telemetryItems:: [{ type: n.type, expr: n.expr }],
    data: query(n.datasource, n._telemetryItems, n._params.from, n._params.to),
    local records = std.reverse(std.sort(
      std.get(n.data.results[0], 'records', []),
      function(rec) rec.timestamp
    )),
    links:
      if record == null then {}
      else {
        [rec.id]: record.graphNode { type: n.type, datasource: n.datasource, id: rec.id }
        for rec in records
        if std.get(rec, 'id', '') != ''
      },
    _view:: {
      local hasRecords = std.length(records) > 0,
      local nav = timeRange.element {
        from:: n._params.from,
        to:: n._params.to,
        resultTo:: if hasRecords then records[0].timestamp else null,
        resultFrom:: if hasRecords then records[std.length(records) - 1].timestamp else null,
      },
      fragment: [
        timeRange.script.html,
        nav.html,
        logs {
          records:: records,
          links:: { [id]: n.links[id]._queryPath for id in std.objectFields(n.links) },
          columns:: n.columns,
        },
        nav.html,
      ],
      page: ui.page {
        fragment:: n._view.fragment,
        breadcrumbs:: ui.breadcrumbs { pathTemplate:: std.get(n, '_pathTemplate', []), node:: n },
      },
      html: html.manifestHtml(self.page),
    },
  }
