local paramsLib = import 'params.libsonnet';

local style = |||
  @scope (.table-filters) {
    :scope.card {
      padding: 0.25em;
    }
    :scope {
      font-family: monospace;
    }
    summary {
      cursor: pointer;
      color: var(--primary-color);
      padding: 0.3em 0.4em;
      user-select: none;
    }
    form {
      display: flex;
      flex-wrap: wrap;
      align-items: flex-end;
      gap: 0.5em 1em;
      margin: 0;
      padding: 0.3em 0.4em 0.6em;
    }
    label {
      display: flex;
      flex-direction: column;
      gap: 0.2em;
    }
    .values {
      display: flex;
      flex-direction: column;
      gap: 0.2em;
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
    .buttons {
      display: flex;
      align-items: center;
      gap: 0.75em;
    }
    button {
      font-family: inherit;
      font-size: inherit;
      color: var(--on-background-color);
      background-color: var(--container-low-color);
      border: 1px solid var(--border-color);
      border-radius: 0.5em;
      padding: 0.3em 1em;
      cursor: pointer;
    }
    button:hover, button:focus {
      color: var(--primary-color);
      border-color: var(--primary-color);
    }
    a {
      color: var(--primary-color);
    }
  }
|||;

local isSet(value) = value != null && value != '' && value != [];

local roleOf(spec) = std.get(spec, 'role', null);

local field = {
  local c = self,
  spec:: error 'field requires a spec',
  value:: null,
  html: {
    element: 'label',
    children: [
      { element: 'span', children: [c.spec.name] },
      if c.spec.type == 'array' then {
        element: 'div',
        attributes: { class: 'values' },
        children: [paramsLib.arrayControl { spec:: c.spec, value:: c.value }],
      }
      else paramsLib.scalarControl { spec:: c.spec, value:: c.value },
    ],
  },
};

local clearLink = {
  local c = self,
  href:: error 'clearLink requires an href',
  html: { element: 'a', attributes: { href: c.href }, children: ['Clear'] },
};

{
  local c = self,
  paramSpecs:: [],
  params:: {},
  clearHref:: null,
  local filterSpecs = [spec for spec in c.paramSpecs if roleOf(spec) == 'filter'],
  local keptSpecs = [spec for spec in c.paramSpecs if !std.member(['filter', 'pagination'], roleOf(spec))],
  local active = std.length([spec for spec in filterSpecs if isSet(std.get(c.params, spec.name, null))]),
  visible:: std.length(filterSpecs) > 0,
  html: [
    { element: 'style', children: [style] },
    {
      element: 'details',
      attributes: { class: 'card table-filters', open: true },
      children: [
        { element: 'summary', children: [if active > 0 then 'Filters (%d)' % active else 'Filters'] },
        {
          element: 'form',
          attributes: { method: 'get' },
          children:
            [field { spec:: spec, value:: std.get(c.params, spec.name, null) } for spec in filterSpecs] +
            [paramsLib.hiddenControl { name:: spec.name, value:: std.get(c.params, spec.name, null) } for spec in keptSpecs] +
            [{
              element: 'div',
              attributes: { class: 'buttons' },
              children:
                [{ element: 'button', attributes: { type: 'submit' }, children: ['Apply'] }] +
                (if active > 0 && c.clearHref != null then [clearLink { href:: c.clearHref }] else []),
            }],
        },
      ],
    },
  ],
}
