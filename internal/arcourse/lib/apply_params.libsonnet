local specByName(specs) = {
  [spec.name]: spec
  for spec in specs
};

local coerceScalar(type, value) =
  if type == 'string' then
    if std.isString(value) then value
    else error 'parameter value %s cannot be coerced to string' % std.manifestJsonEx(value, '')
  else if type == 'number' then
    if std.isNumber(value) then value
    else error 'parameter value %s cannot be coerced to number' % std.manifestJsonEx(value, '')
  else if type == 'boolean' then
    if std.isBoolean(value) then value
    else error 'parameter value %s cannot be coerced to boolean' % std.manifestJsonEx(value, '')
  else
    error 'unknown scalar type %s' % type;

local coerceElement(type, value) =
  if type == 'string' then
    if std.isString(value) then value
    else error 'array element %s cannot be coerced to string' % std.manifestJsonEx(value, '')
  else if type == 'number' then
    if std.isNumber(value) then value
    else error 'array element %s cannot be coerced to number' % std.manifestJsonEx(value, '')
  else if type == 'boolean' then
    if std.isBoolean(value) then value
    else error 'array element %s cannot be coerced to boolean' % std.manifestJsonEx(value, '')
  else
    error 'unknown array element type %s' % type;

local coerceRawValue(spec, raw, label='parameter value') =
  if spec.type == 'string' then
    if std.isString(raw) then raw
    else error '%s %s cannot be coerced to string' % [label, std.manifestJsonEx(raw, '')]
  else if spec.type == 'array' then
    local value = if std.isString(raw) then std.parseJson(raw) else raw;
    if !std.isArray(value) then
      error '%s %s cannot be coerced to array' % [label, std.manifestJsonEx(value, '')]
    else
      [coerceRawValue({ type: spec.items }, element, 'array element') for element in value]
  else
    local value = if std.isString(raw) then std.parseJson(raw) else raw;
    if label == 'array element' then
      coerceElement(spec.type, value)
    else
      coerceScalar(spec.type, value);

local resolveParam(spec, params) =
  local name = spec.name;
  if std.objectHas(params, name) then
    coerceRawValue(spec, params[name])
  else if std.objectHas(spec, 'default') then
    spec.default
  else
    error 'required parameter %s is missing' % name;

function(node, params)
  local specs = if std.objectHasAll(node, '_params') then node._params else [];
  local paramKeys = std.objectFields(params);

  if std.length(specs) == 0 then
    if std.length(paramKeys) > 0 then
      error 'node does not accept parameters'
    else
      node
  else
    local specsByName = specByName(specs);
    local validated = std.foldl(
      function(acc, key)
        if std.objectHas(specsByName, key) then acc
        else error 'undeclared parameter %s' % key,
      paramKeys,
      {},
    );
    local resolved = {
      [spec.name]: resolveParam(spec, params)
      for spec in specs
    };
    node + validated + resolved
