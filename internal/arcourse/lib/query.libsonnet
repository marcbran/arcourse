local applyParams = import 'apply_params.libsonnet';
local traversePath = import 'traverse_path.libsonnet';
local truncateNode = import 'truncate_node.libsonnet';

function(root, segments, params, formats)
  local merged = applyParams(traversePath(root, segments), params);
  local evaluationId = std.native('invoke:arcourse')('uuid', []);
  local identified = merged + { _evaluationId: evaluationId };
  local view = if std.objectHasAll(identified, '_view') then identified._view else {};
  local fields = { json: truncateNode(identified, 'query') } +
    (if std.objectHasAll(view, 'html') then { html: view.html } else {}) +
    (if std.objectHasAll(view, 'jsonnet') then { jsonnet: view.jsonnet } else {});
  { [f]: fields[f] for f in formats if std.objectHas(fields, f) } + { _evaluationId: evaluationId }
