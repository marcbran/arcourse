local style = |||
  @scope (.status-card) {
    :scope.card {
      display: inline-flex;
      flex-direction: column;
      gap: 0.5em;
      padding: 0.75em 1em;
      border-color: var(--error-color);
      font-family: monospace;
    }
    .status-title {
      margin: 0;
      color: var(--error-color);
      font-weight: bold;
    }
    .status-message {
      margin: 0;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
    }
  }
|||;

{
  local c = self,
  status:: error 'Status requires status',
  local code = std.get(c.status, 'code', null),
  local reason = std.get(c.status, 'reason', null),
  local message = std.get(c.status, 'message', null),
  local title = std.join(' ', [std.toString(part) for part in [code, reason] if part != null && part != '']),
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'card status-card', role: 'alert' },
      children: [
        { element: 'p', attributes: { class: 'status-title' }, children: [if title == '' then 'Failure' else title] },
      ] + (
        if message == null || message == '' then []
        else [{ element: 'p', attributes: { class: 'status-message' }, children: [std.toString(message)] }]
      ),
    },
  ],
}
