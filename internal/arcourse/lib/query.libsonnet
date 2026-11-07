local failure = import 'arcourse-graph/failure.libsonnet';
local applyParams = import 'apply_params.libsonnet';
local failurePage = import 'failure_page.libsonnet';
local traversePath = import 'traverse_path.libsonnet';
local truncateNode = import 'truncate_node.libsonnet';

function(root, segments, params, formats)
  local found = traversePath(root, segments);
  local merged = if failure.isFailure(found) then found else applyParams(found, params);
  local evaluationId = std.native('invoke:arcourse')('uuid', []);
  local fields =
    if failure.isFailure(merged) then
      {
        json: { _failure: merged._failure, _evaluationId: evaluationId },
        html: failurePage(merged._failure, 'html'),
      }
    else
      local identified = merged + { _evaluationId: evaluationId };
      local view = if std.objectHasAll(identified, '_view') then identified._view else {};
      { json: truncateNode(identified, 'query') } +
      (if std.objectHasAll(view, 'html') then { html: view.html } else {}) +
      (if std.objectHasAll(view, 'jsonnet') then { jsonnet: view.jsonnet } else {});
  { [f]: fields[f] for f in formats if std.objectHas(fields, f) } + { _evaluationId: evaluationId }
