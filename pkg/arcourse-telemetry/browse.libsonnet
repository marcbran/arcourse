local query = import 'query.libsonnet';

local result(datasource, expr, from='now-5m', to='now') =
  query(datasource, [{ type: 'promql', expr: expr, instant: true }], from, to).results[0];

local labelValues(result, label) = [
  v
  for s in result.series
  for v in [std.get(s.labels, label, null)]
  if v != null
];

local labelNames(result) =
  std.set(std.flattenArrays([
    [k for k in std.objectFields(s.labels) if k != '__name__']
    for s in result.series
  ]));

local defaultGroup(n) = n._pathTemplate[std.length(n._pathTemplate) - 1];

{
  result: result,
  labelValues: labelValues,
  labelNames: labelNames,
  defaultGroup: defaultGroup,
}
