local pageStyle = |||
  * {
    margin: 0;
    padding: 0;
  }
  :root {
    color-scheme: light dark;
    --primary-color: light-dark(#0451a5, #569cd6);
    --background-color: light-dark(
      color-mix(in srgb, var(--primary-color) 3%, white),
      color-mix(in srgb, var(--primary-color) 8%, black)
    );
    --border-color: light-dark(
      color-mix(in srgb, var(--primary-color) 20%, white),
      color-mix(in srgb, var(--primary-color) 30%, black)
    );
  }
  body {
    background-color: var(--background-color);
    padding: 0.5em;
  }
|||;

{
  local c = self,
  fragment:: error 'HtmlPage requires a fragment',
  html: [
    { doctype: 'html' },
    {
      element: 'html',
      children: [
        { element: 'head', children: [{ element: 'style', children: [pageStyle] }] },
        { element: 'body', children: [c.fragment] },
      ],
    },
  ],
}
