local nestedMappingsFor = import 'list-detail-nested.jsonnet';

local responseRefName(ref) = std.strReplace(ref, '#/components/responses/', '');
local schemaRefName(ref) = std.strReplace(ref, '#/components/schemas/', '');

local pathPartName(part) =
  if std.length(part) >= 2 && part[0] == '{' && part[std.length(part) - 1] == '}'
  then '_' + std.substr(part, 1, std.length(part) - 2)
  else part;
local bundleName(path) =
  local parts = [pathPartName(part) for part in std.split(path, '/') if part != ''];
  if std.length(parts) == 0 then '_root' else std.join('__', parts);

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

local isArraySchema(schema) =
  std.type(schema) == 'object' &&
  std.get(schema, 'type', null) == 'array';
local responseArrays(spec, schema) =
  if isArraySchema(schema) then [
    {
      array: [],
      itemSchema: resolveSchema(spec, std.get(schema, 'items', null)),
    },
  ]
  else if std.type(schema) == 'object' &&
          std.get(schema, 'type', null) == 'object' &&
          std.objectHas(schema, 'properties') then [
    {
      array: [property],
      itemSchema: resolveSchema(spec, std.get(schema.properties[property], 'items', null)),
    }
    for property in std.objectFields(schema.properties)
    if isArraySchema(schema.properties[property])
  ]
  else [];

local listPathBundle(spec, result, sourcePath) =
  local response = std.get(std.get(spec.paths[sourcePath].get, 'responses', {}), '200', null);
  local schema = responseSchema(spec, response);
  {
    sourcePath: sourcePath,
    arrays: responseArrays(spec, schema),
    detailPaths: result.detailPaths,
  };

function(spec)
  local result = nestedMappingsFor(spec);
  {
    [bundleName(sourcePath)]: {
      'input.json': std.manifestJsonEx(
        listPathBundle(spec, result, sourcePath),
        '  ',
      ),
    }
    for sourcePath in result.unmappedListPaths
  }
