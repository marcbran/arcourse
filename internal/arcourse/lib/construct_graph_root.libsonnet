local g = import 'arcourse-graph/main.libsonnet';

function(graphSpec)
  local nodeSpecs = graphSpec[0];
  local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
  g.graph(nodeSpecs, defaultView)
