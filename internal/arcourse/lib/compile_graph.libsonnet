local g = import 'arcourse-graph/main.libsonnet';

function(graphSpec)
  local nodeSpecs = graphSpec[0];
  g.shape(g.toLayers(nodeSpecs))
