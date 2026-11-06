local style = |||
  @scope (.failure-card) {
    :scope.card {
      display: inline-flex;
      flex-direction: column;
      gap: 0.5em;
      padding: 0.75em 1em;
      border-color: var(--error-color);
      font-family: monospace;
    }
    .failure-title {
      margin: 0;
      color: var(--error-color);
      font-weight: bold;
    }
    .failure-message {
      margin: 0;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
    }
  }
|||;

{
  local c = self,
  failure:: error 'Failure requires failure',
  local code = std.get(c.failure, 'code', null),
  local reason = std.get(c.failure, 'reason', null),
  local message = std.get(c.failure, 'message', null),
  local title = std.join(' ', [std.toString(part) for part in [code, reason] if part != null && part != '']),
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'card failure-card', role: 'alert' },
      children: [
        { element: 'p', attributes: { class: 'failure-title' }, children: [if title == '' then 'Failure' else title] },
      ] + (
        if message == null || message == '' then []
        else [{ element: 'p', attributes: { class: 'failure-message' }, children: [std.toString(message)] }]
      ),
    },
  ],
}
