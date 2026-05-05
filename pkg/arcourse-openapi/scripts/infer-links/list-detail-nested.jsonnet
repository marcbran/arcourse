local listPathsFor = import 'list-paths.jsonnet';
local detailPathsFor = import 'detail-paths.jsonnet';

local splitPath(path) = [part for part in std.split(path, '/') if part != ''];
local joinPath(parts) = '/' + std.join('/', parts);
local parentPath(path) =
  local parts = splitPath(path);
  if std.length(parts) <= 1 then null else joinPath(std.slice(parts, 0, std.length(parts) - 1, 1));

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

local isArrayOfRef(schema) =
  std.type(schema) == 'object' &&
  std.get(schema, 'type', null) == 'array' &&
  std.type(std.get(schema, 'items', null)) == 'object' &&
  std.objectFields(schema.items) == ['$ref'];
local arrayRefs(schema) =
  if isArrayOfRef(schema) then [
    {
      array: [],
      ref: schema.items['$ref'],
    },
  ]
  else if std.type(schema) == 'object' &&
          std.get(schema, 'type', null) == 'object' &&
          std.objectHas(schema, 'properties') then [
    {
      array: [property],
      ref: schema.properties[property].items['$ref'],
    }
    for property in std.objectFields(schema.properties)
    if isArrayOfRef(schema.properties[property])
  ]
  else [];

local uniqueRefs(refs) =
  std.foldl(function(acc, ref) if std.member(acc, ref) then acc else acc + [ref], refs, []);
local contains(values, value) = std.member(values, value);

function(spec)
  local detailPaths = detailPathsFor(spec);
  local listPaths = listPathsFor(spec);
  local mappings = [
    {
      sourcePath: sourcePath,
      targetPath: detailPath,
      array: arrayRef.array,
    }
    for detailPath in detailPaths
    for sourcePath in [parentPath(detailPath)]
    if sourcePath != null && contains(listPaths, sourcePath)
    for sourceResponse in [std.get(std.get(spec.paths[sourcePath].get, 'responses', {}), '200', null)]
    for sourceSchema in [responseSchema(spec, sourceResponse)]
    for sourceArrayRefs in [arrayRefs(sourceSchema)]
    if std.length(sourceArrayRefs) == 1
    for arrayRef in sourceArrayRefs
  ];
  local mappedListPaths = uniqueRefs([mapping.sourcePath for mapping in mappings]);
  {
    mappings: mappings,
    unmappedListPaths: [
      path
      for path in listPaths
      if !contains(mappedListPaths, path)
    ],
    detailPaths: detailPaths,
  }
