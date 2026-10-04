local style = |||
  .preview {
    flex: 1 1 100%;
    min-width: 0;
    height: 70vh;
    border: 1px solid var(--border-color);
    background: var(--background-color);
  }
|||;

{
  local c = self,
  src:: error 'Preview requires a src',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'iframe',
      attributes: {
        class: 'preview card',
        src: c.src,
        sandbox: '',
        loading: 'lazy',
      },
      children: [],
    },
  ],
}
