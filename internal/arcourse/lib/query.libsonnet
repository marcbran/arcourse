local applyParams = import 'apply_params.libsonnet';
local traversePath = import 'traverse_path.libsonnet';
local truncateNode = import 'truncate_node.libsonnet';

function(root, segments, params, formats)
  local merged = applyParams(traversePath(root, segments), params);
  local fields = {
    json: truncateNode(merged, 'query'),
    html: merged._view.html,
    jsonnet: merged._view.jsonnet,
  };
  { [f]: fields[f] for f in formats }
