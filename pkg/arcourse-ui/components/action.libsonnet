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
  }
|||;

{
  local c = self,
  evaluationId:: error 'Action requires an evaluationId',
  summary:: '',
  label:: 'Apply',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'action card' },
      children:
        (if c.summary != '' then [{ element: 'p', children: [c.summary] }] else []) +
        [
          {
            element: 'form',
            attributes: { method: 'post', action: '/exec' },
            children: [
              { element: 'input', attributes: { type: 'hidden', name: 'evaluationId', value: c.evaluationId } },
              { element: 'button', attributes: { type: 'submit' }, children: [c.label] },
            ],
          },
        ],
    },
  ],
}
