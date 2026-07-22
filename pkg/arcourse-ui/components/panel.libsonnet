{
  local c = self,
  child:: error 'Panel requires a child',
  style:: '',
  html: {
    element: 'div',
    attributes: { style: 'display: inline-block; border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.75em 1em;' + c.style },
    children: [c.child],
  },
}
