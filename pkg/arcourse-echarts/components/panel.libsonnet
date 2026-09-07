local style = |||
  @scope (.panel) {
    :scope {
      display: block;
      width: 100%;
      box-sizing: border-box;
      padding: 0.25em;
    }
  }
|||;

{
  local c = self,
  child:: error 'Panel requires a child',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'card panel' },
      children: [c.child],
    },
  ],
}
