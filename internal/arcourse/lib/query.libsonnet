local applyParams = import 'apply_params.libsonnet';
local traversePath = import 'traverse_path.libsonnet';
local truncateNode = import 'truncate_node.libsonnet';

function(root, segments, params)
  truncateNode(applyParams(traversePath(root, segments), params), 'query')
