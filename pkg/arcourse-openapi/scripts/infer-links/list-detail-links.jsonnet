local mappingsFor = import 'list-detail-mappings.jsonnet';

local varsObject(vars) = {
  [item.param]: item.path
  for item in vars
};

local matchingVars(varsInferred, mapping) = [
  item
  for item in varsInferred
  if item.sourcePath == mapping.sourcePath &&
     item.targetPath == mapping.targetPath &&
     item.array == mapping.array
];

function(spec, inferred, varsInferred)
  [
    {
      sourcePath: mapping.sourcePath,
      targetPath: mapping.targetPath,
      array: mapping.array,
      vars: varsObject(if std.length(matches) == 0 then [] else matches[0].vars),
    }
    for mapping in mappingsFor(spec, inferred)
    for matches in [matchingVars(varsInferred, mapping)]
  ]
