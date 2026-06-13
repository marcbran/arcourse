local applyParams = import 'apply_params.libsonnet';
local traversePath = import 'traverse_path.libsonnet';

function(root, segments, params)
  applyParams(traversePath(root, segments), params)
