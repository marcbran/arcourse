local nestedFor = import 'list-detail-nested.jsonnet';

local mapping(item) = {
  sourcePath: item.sourcePath,
  targetPath: item.targetPath,
  array: item.array,
};

function(spec, inferred=import 'list-detail-inference/results/all.jsonnet')
  [mapping(item) for item in nestedFor(spec).mappings] +
  [
    mapping(item)
    for item in inferred
    if item.classification == 'detail_elsewhere'
  ]
