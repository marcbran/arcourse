local specByName(specs) = {
  [spec.name]: spec
  for spec in specs
};

local ok(value) = { value: value };
local problem(message) = { problem: message };
local isProblem(result) = std.objectHas(result, 'problem');

local manifest(value) = std.manifestJsonEx(value, '');

local matches(type, value) =
  if type == 'string' then std.isString(value)
  else if type == 'number' then std.isNumber(value)
  else if type == 'boolean' then std.isBoolean(value)
  else error 'unknown parameter type %s' % type;

local isNumeric(s) =
  local chars = std.stringChars(s);
  std.length(chars) > 0
  && std.all([std.member('0123456789+-.eE', c) for c in chars])
  && std.any([std.member('0123456789', c) for c in chars]);

local parseScalar(type, raw) =
  if !std.isString(raw) then raw
  else if type == 'number' && isNumeric(raw) then std.parseJson(raw)
  else if type == 'boolean' && (raw == 'true' || raw == 'false') then raw == 'true'
  else raw;

local checkEnum(spec, result, label) =
  if isProblem(result) || !std.objectHas(spec, 'enum') || std.member(spec.enum, result.value) then result
  else problem('%s %s is not one of %s' % [label, manifest(result.value), std.join(', ', [manifest(v) for v in spec.enum])]);

local coerceType(spec, raw, label) =
  if spec.type == 'string' then
    if std.isString(raw) then ok(raw)
    else problem('%s %s cannot be coerced to string' % [label, manifest(raw)])
  else if spec.type == 'array' then
    local value = if std.isString(raw) && label == 'parameter value' then [raw] else raw;
    if !std.isArray(value) then
      problem('%s %s cannot be coerced to array' % [label, manifest(value)])
    else
      local itemSpec = if std.isObject(spec.items) then spec.items else { type: spec.items };
      local items = [checkEnum(itemSpec, coerceType(itemSpec, element, 'array element'), 'array element') for element in value];
      local problems = [item.problem for item in items if isProblem(item)];
      if std.length(problems) > 0 then problem(problems[0])
      else ok([item.value for item in items])
  else
    local value = parseScalar(spec.type, raw);
    if matches(spec.type, value) then ok(value)
    else problem('%s %s cannot be coerced to %s' % [label, manifest(raw), spec.type]);

local coerceRawValue(spec, raw) =
  checkEnum(spec, coerceType(spec, raw, 'parameter value'), 'parameter value');

local resolveParam(spec, params, nodeParams) =
  local name = spec.name;
  if std.objectHas(params, name) && params[name] != '' then
    coerceRawValue(spec, params[name])
  else if std.objectHas(nodeParams, name) then
    ok(nodeParams[name])
  else if std.objectHas(spec, 'default') then
    ok(spec.default)
  else
    problem('required parameter %s is missing' % name);

local badRequest(problems) = {
  _failure: { code: 400, reason: 'Bad Request', message: std.join('; ', problems) },
};

function(node, params)
  local specs = if std.objectHasAll(node, '_paramSpecs') then node._paramSpecs else [];
  local paramKeys = std.objectFields(params);

  if std.length(specs) == 0 then
    if std.length(paramKeys) > 0 then
      badRequest(['node does not accept parameters'])
    else
      node
  else
    local specsByName = specByName(specs);
    local nodeParams = std.get(node, '_params', {});
    local results = [{ name: spec.name, result: resolveParam(spec, params, nodeParams) } for spec in specs];
    local problems =
      ['undeclared parameter %s' % key for key in paramKeys if !std.objectHas(specsByName, key)]
      + [entry.result.problem for entry in results if isProblem(entry.result)];
    if std.length(problems) > 0 then
      badRequest(problems)
    else
      local resolved = {
        [entry.name]: entry.result.value
        for entry in results
        if entry.result.value != null
      };
      node + { _params::: resolved }
