local text(value) = if value == null then null else std.toString(value);

local option = {
  local c = self,
  value:: error 'option requires a value',
  selected:: false,
  html: {
    element: 'option',
    attributes: { value: c.value, selected: c.selected },
    children: [c.value],
  },
};

local numberControl = {
  local c = self,
  name:: error 'numberControl requires a name',
  value:: null,
  html: {
    element: 'input',
    attributes: { type: 'number', step: 'any', name: c.name, value: text(c.value) },
  },
};

local textControl = {
  local c = self,
  name:: error 'textControl requires a name',
  value:: null,
  html: {
    element: 'input',
    attributes: { type: 'text', name: c.name, value: c.value },
  },
};

local selectControl = {
  local c = self,
  name:: error 'selectControl requires a name',
  options:: error 'selectControl requires options',
  value:: null,
  local current = if c.value == null then '' else std.toString(c.value),
  html: {
    element: 'select',
    attributes: { name: c.name },
    children: [
      option { value:: v, selected:: v == current }
      for v in [''] + c.options
    ],
  },
};

local multiSelectControl = {
  local c = self,
  name:: error 'multiSelectControl requires a name',
  options:: error 'multiSelectControl requires options',
  value:: null,
  local current = [std.toString(v) for v in (if c.value == null then [] else c.value)],
  html: {
    element: 'select',
    attributes: { name: c.name, multiple: true, size: std.min(std.length(c.options), 6) },
    children: [
      option { value:: v, selected:: std.member(current, v) }
      for v in c.options
    ],
  },
};

local repeatedTextControl = {
  local c = self,
  name:: error 'repeatedTextControl requires a name',
  value:: null,
  html: [
    { element: 'input', attributes: { type: 'text', name: c.name, value: v } }
    for v in [std.toString(v) for v in (if c.value == null then [] else c.value)] + ['']
  ],
};

local hiddenControl = {
  local c = self,
  name:: error 'hiddenControl requires a name',
  value:: null,
  html: [
    { element: 'input', attributes: { type: 'hidden', name: c.name, value: std.toString(v) } }
    for v in if c.value == null then [] else if std.isArray(c.value) then c.value else [c.value]
  ],
};

local enumOf(spec) = [std.toString(v) for v in std.get(spec, 'enum', [])];

local itemSpec(spec) =
  local items = std.get(spec, 'items', 'string');
  if std.isObject(items) then items else { type: items };

local scalarTypes = ['number', 'string', 'boolean'];

local scalarControl = {
  local c = self,
  spec:: error 'scalarControl requires a spec',
  name:: c.spec.name,
  value:: null,
  local enum = enumOf(c.spec),
  html:
    if std.length(enum) > 0 then (selectControl { name:: c.name, options:: enum, value:: c.value }).html
    else if c.spec.type == 'boolean' then (selectControl { name:: c.name, options:: ['true', 'false'], value:: c.value }).html
    else if c.spec.type == 'number' then (numberControl { name:: c.name, value:: c.value }).html
    else (textControl { name:: c.name, value:: c.value }).html,
};

local arrayControl = {
  local c = self,
  spec:: error 'arrayControl requires a spec',
  name:: c.spec.name,
  value:: null,
  local enum = enumOf(itemSpec(c.spec)),
  html:
    if std.length(enum) > 0 then (multiSelectControl { name:: c.name, options:: enum, value:: c.value }).html
    else (repeatedTextControl { name:: c.name, value:: c.value }).html,
};

{
  scalarTypes: scalarTypes,
  scalarControl: scalarControl,
  arrayControl: arrayControl,
  hiddenControl: hiddenControl,
}
