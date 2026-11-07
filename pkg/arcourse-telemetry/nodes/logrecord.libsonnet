local ui = import '../../arcourse-ui/main.libsonnet';

function(telemetry)
  ui.resource.node {
    local n = self,
    response:: telemetry.fetch(n.type, n.datasource, n.id),
    data: n.response.record,
  }
