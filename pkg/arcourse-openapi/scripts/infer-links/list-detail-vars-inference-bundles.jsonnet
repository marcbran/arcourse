local mappingsFor = import 'list-detail-mappings.jsonnet';

local responseRefName(ref) = std.strReplace(ref, '#/components/responses/', '');
local schemaRefName(ref) = std.strReplace(ref, '#/components/schemas/', '');

local splitPath(path) = [part for part in std.split(path, '/') if part != ''];
local pathParam(part) =
  if std.length(part) >= 2 && part[0] == '{' && part[std.length(part) - 1] == '}'
  then std.substr(part, 1, std.length(part) - 2)
  else null;
local pathParams(path) = [
  param
  for part in splitPath(path)
  for param in [pathParam(part)]
  if param != null
];
local contains(values, value) = std.member(values, value);
local commonPrefixLength(left, right) =
  if std.length(left) == 0 || std.length(right) == 0 || left[0] != right[0] then 0
  else 1 + commonPrefixLength(
    std.slice(left, 1, std.length(left), 1),
    std.slice(right, 1, std.length(right), 1),
  );
local inheritedParams(sourcePath, targetPath) =
  local sourceParts = splitPath(sourcePath);
  local targetParts = splitPath(targetPath);
  local commonLength = commonPrefixLength(sourceParts, targetParts);
  local targetIsSourceParent = commonLength == std.length(targetParts) && std.length(sourceParts) > std.length(targetParts);
  if targetIsSourceParent then []
  else [
    param
    for i in std.range(0, commonLength - 1)
    for param in [pathParam(targetParts[i])]
    if param != null
  ];
local missingParams(sourcePath, targetPath) =
  local inherited = inheritedParams(sourcePath, targetPath);
  [
    param
    for param in pathParams(targetPath)
    if !contains(inherited, param)
  ];

local pathPartName(part) =
  if std.length(part) >= 2 && part[0] == '{' && part[std.length(part) - 1] == '}'
  then '_' + std.substr(part, 1, std.length(part) - 2)
  else part;
local bundlePathName(path) =
  local parts = [pathPartName(part) for part in splitPath(path)];
  if std.length(parts) == 0 then '_root' else std.join('__', parts);
local bundleName(mapping) =
  bundlePathName(mapping.sourcePath) + '--' + bundlePathName(mapping.targetPath);

local responseSchema(spec, response) =
  local resolved =
    if std.type(response) == 'object' &&
       std.objectHas(response, '$ref') &&
       std.startsWith(response['$ref'], '#/components/responses/')
    then spec.components.responses[responseRefName(response['$ref'])]
    else response;
  local content = std.get(resolved, 'content', {});
  local contentTypes = std.objectFields(content);
  local child =
    if std.objectHas(content, 'application/json') then content['application/json']
    else if std.length(contentTypes) > 0 then content[contentTypes[0]]
    else {};
  std.get(child, 'schema', null);

local resolveSchema(spec, schema) =
  if std.type(schema) == 'object' &&
     std.objectHas(schema, '$ref') &&
     std.startsWith(schema['$ref'], '#/components/schemas/')
  then spec.components.schemas[schemaRefName(schema['$ref'])]
  else schema;

local arrayItemSchema(spec, schema, array) =
  if std.length(array) == 0 then
    resolveSchema(spec, std.get(schema, 'items', null))
  else if std.length(array) == 1 &&
          std.type(schema) == 'object' &&
          std.objectHas(schema, 'properties') &&
          std.objectHas(schema.properties, array[0]) then
    resolveSchema(spec, std.get(schema.properties[array[0]], 'items', null))
  else null;

local bundle(spec, mapping) =
  local response = std.get(std.get(spec.paths[mapping.sourcePath].get, 'responses', {}), '200', null);
  local schema = responseSchema(spec, response);
  {
    sourcePath: mapping.sourcePath,
    targetPath: mapping.targetPath,
    array: mapping.array,
    sourceParams: pathParams(mapping.sourcePath),
    inheritedParams: inheritedParams(mapping.sourcePath, mapping.targetPath),
    targetParams: pathParams(mapping.targetPath),
    missingParams: missingParams(mapping.sourcePath, mapping.targetPath),
    itemSchema: arrayItemSchema(spec, schema, mapping.array),
  };

function(spec, inferred=import 'list-detail-inference/results/all.jsonnet')
  {
    [bundleName(mapping)]: {
      'input.json': std.manifestJsonEx(bundle(spec, mapping), '  '),
    }
    for mapping in mappingsFor(spec, inferred)
    if std.length(missingParams(mapping.sourcePath, mapping.targetPath)) > 0
  }
