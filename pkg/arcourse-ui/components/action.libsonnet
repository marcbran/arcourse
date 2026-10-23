local script = importstr 'action-card.js';

local style = |||
  @scope (.action) {
    :scope {
      font-family: monospace;
      display: inline-flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 0.75em;
      padding: 0.5em;
    }
    p {
      margin: 0;
    }
    form {
      margin: 0;
    }
    form.params {
      display: flex;
      flex-direction: column;
      gap: 0.5em;
    }
    label {
      display: flex;
      align-items: baseline;
      gap: 0.75em;
    }
    input, select {
      font-family: inherit;
      font-size: inherit;
      color: var(--on-background-color);
      background-color: var(--container-low-color);
      border: 1px solid var(--border-color);
      border-radius: 0.5em;
      padding: 0.3em 0.6em;
    }
    input:focus, select:focus {
      outline: 2px solid var(--primary-color);
      outline-offset: 2px;
    }
    .issue {
      color: var(--error-color);
    }
    .issue.hint {
      color: inherit;
      opacity: 0.6;
    }
    .buttons {
      display: flex;
      gap: 0.5em;
      align-self: flex-end;
    }
    button {
      font-family: inherit;
      font-size: inherit;
      color: var(--on-background-color);
      background-color: var(--container-low-color);
      border: 1px solid var(--border-color);
      border-radius: 0.5em;
      padding: 0.4em 1em;
      cursor: pointer;
    }
    button:hover {
      color: var(--primary-color);
      border-color: var(--primary-color);
    }
    button:focus {
      outline: 2px solid var(--primary-color);
      outline-offset: 2px;
    }
    button:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }
    button:disabled:hover {
      color: var(--on-background-color);
      border-color: var(--border-color);
    }
  }
|||;

local paramsFormId = 'action-params';

local issue = {
  local c = self,
  message:: error 'issue requires a message',
  hint:: false,
  html: {
    element: 'p',
    attributes: { class: if c.hint then 'issue hint' else 'issue' },
    children: [c.message],
  },
};

local numberControl = {
  local c = self,
  name:: error 'numberControl requires a name',
  value:: null,
  html: {
    element: 'input',
    attributes: { type: 'number', step: 'any', name: c.name, value: if c.value == null then null else std.toString(c.value) },
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

local booleanOption = {
  local c = self,
  value:: error 'booleanOption requires a value',
  selected:: false,
  html: {
    element: 'option',
    attributes: { value: c.value, selected: c.selected },
    children: [c.value],
  },
};

local booleanControl = {
  local c = self,
  name:: error 'booleanControl requires a name',
  value:: null,
  local current = if c.value == null then '' else std.toString(c.value),
  html: {
    element: 'select',
    attributes: { name: c.name },
    children: [
      booleanOption { value:: v, selected:: v == current }
      for v in ['', 'true', 'false']
    ],
  },
};

local hiddenControl = {
  local c = self,
  name:: error 'hiddenControl requires a name',
  value:: null,
  html:
    if c.value == null then []
    else [{
      element: 'input',
      attributes: { type: 'hidden', name: c.name, value: std.manifestJsonMinified(c.value) },
    }],
};

local controls = {
  number: numberControl,
  string: textControl,
  boolean: booleanControl,
};

local field = {
  local c = self,
  spec:: error 'field requires a spec',
  params:: {},
  initialValues:: {},
  issues:: [],
  local name = c.spec.name,
  local present = std.objectHas(c.params, name),
  local initial = std.objectHas(c.initialValues, name),
  local value = if present then c.params[name] else if initial then c.initialValues[name] else null,
  html:
    if std.objectHas(controls, c.spec.type) then [{
      element: 'label',
      children: [
        { element: 'span', children: [name] },
        controls[c.spec.type] { name:: name, value:: value },
      ],
    }] + [
      issue { message:: i.message, hint:: !present }
      for i in c.issues
      if present || !initial
    ]
    else hiddenControl { name:: name, value:: value },
};

local paramsForm = {
  local c = self,
  paramSpecs:: [],
  params:: {},
  initialValues:: {},
  issues:: [],
  html: {
    element: 'form',
    attributes: { id: paramsFormId, class: 'params', method: 'get' },
    children: [
      field {
        spec:: spec,
        params:: c.params,
        initialValues:: c.initialValues,
        issues:: [i for i in c.issues if std.get(i, 'param', null) == spec.name],
      }
      for spec in c.paramSpecs
    ],
  },
};

local planButton = {
  html: {
    element: 'button',
    attributes: { type: 'submit', form: paramsFormId },
    children: ['Plan'],
  },
};

local applyForm = {
  local c = self,
  evaluationId:: error 'applyForm requires an evaluationId',
  label:: 'Apply',
  html: {
    element: 'form',
    attributes: { class: 'apply', method: 'post', action: '/exec' },
    children: [
      { element: 'input', attributes: { type: 'hidden', name: 'evaluationId', value: c.evaluationId } },
      { element: 'button', attributes: { type: 'submit' }, children: [c.label] },
    ],
  },
};

{
  local c = self,
  evaluationId:: error 'Action requires an evaluationId',
  summary:: '',
  label:: 'Apply',
  paramSpecs:: [],
  params:: {},
  initialValues:: {},
  action:: null,
  local hasParams = std.length(c.paramSpecs) > 0,
  local issues = if c.action != null && std.objectHas(c.action, 'issues') then c.action.issues else [],
  local applicable = c.action != null && !std.objectHas(c.action, 'issues'),
  local paramNames = [spec.name for spec in c.paramSpecs if std.objectHas(controls, spec.type)],
  local formIssues = [i for i in issues if !std.member(paramNames, std.get(i, 'param', null))],
  html: [
    { element: 'style', children: [style] },
  ] + (if hasParams then [{ element: 'script', children: [{ html: script }] }] else []) + [
    {
      element: 'action-card',
      attributes: { class: 'action card' },
      children:
        (if c.summary != '' then [{ element: 'p', children: [c.summary] }] else []) +
        [
          issue { message:: if std.objectHas(i, 'param') then '%s: %s' % [i.param, i.message] else i.message }
          for i in formIssues
        ] +
        (if hasParams then [paramsForm { paramSpecs:: c.paramSpecs, params:: c.params, initialValues:: c.initialValues, issues:: issues }] else []) +
        [{
          element: 'div',
          attributes: { class: 'buttons' },
          children:
            (if hasParams then [planButton] else []) +
            (if applicable then [applyForm { evaluationId:: c.evaluationId, label:: c.label }] else []),
        }],
    },
  ],
}
