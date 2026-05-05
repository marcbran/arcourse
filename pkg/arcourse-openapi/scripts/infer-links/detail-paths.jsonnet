local endsWithPathVar(path) =
  std.length(path) >= 2 &&
  path[std.length(path) - 1] == '}' &&
  std.findSubstr('{', path) != [];

local responseRefName(ref) = std.strReplace(ref, '#/components/responses/', '');
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

local isSingleRefSchema(schema) =
  std.type(schema) == 'object' &&
  std.objectFields(schema) == ['$ref'];
local isOneOfRefSchema(schema) =
  std.type(schema) == 'object' &&
  std.objectHas(schema, 'oneOf') &&
  std.length(schema.oneOf) > 0 &&
  std.all([isSingleRefSchema(item) for item in schema.oneOf]);
local isDetailResponseSchema(schema) =
  isSingleRefSchema(schema) || isOneOfRefSchema(schema);

function(spec)
  [
    path
    for path in std.objectFields(spec.paths)
    if std.objectHas(spec.paths[path], 'get')
    if endsWithPathVar(path)
    for response in [std.get(std.get(spec.paths[path].get, 'responses', {}), '200', null)]
    if response != null
    for schema in [responseSchema(spec, response)]
    if isDetailResponseSchema(schema)
  ]
