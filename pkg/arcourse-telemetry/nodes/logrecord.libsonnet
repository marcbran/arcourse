local ui = import '../../arcourse-ui/main.libsonnet';

function(telemetry)
  ui.resource.node {
    local n = self,
    data: telemetry.fetch(n.type, n.datasource, n.id).record,
  }
