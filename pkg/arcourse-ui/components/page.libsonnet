local pageStyle = |||
  * {
    margin: 0;
    padding: 0;
  }
  :root {
    color-scheme: light dark;
    --primary-color: light-dark(#0451a5, #569cd6);
    --on-background-color: light-dark(
      color-mix(in srgb, var(--primary-color) 12%, black),
      color-mix(in srgb, var(--primary-color) 12%, white)
    );
    --background-color: light-dark(
      color-mix(in srgb, var(--primary-color) 3%, white),
      color-mix(in srgb, var(--primary-color) 8%, black)
    );
    --container-low-color: light-dark(
      color-mix(in srgb, var(--primary-color) 8%, white),
      color-mix(in srgb, var(--primary-color) 15%, black)
    );
    --border-color: light-dark(
      color-mix(in srgb, var(--primary-color) 20%, white),
      color-mix(in srgb, var(--primary-color) 30%, black)
    );
  }
  body {
    background-color: var(--background-color);
    color: var(--on-background-color);
    padding: 0.5em;
  }
  .card {
    display: inline-block;
    border: 1px solid var(--border-color);
    border-radius: 0.5em;
    padding: 0.75em;
  }
  .deck {
    display: contents;
  }
  .deck:has(.card ~ .card),
  .deck:has(.list):has(.yaml) {
    display: inline-flex;
    gap: 0.25em;
    border: 1px solid var(--border-color);
    border-radius: 0.5em;
    padding: 0.25em;
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
        {
          element: 'body',
          children: [{ element: 'div', attributes: { class: 'deck' }, children: c.fragment }],
        },
      ],
    },
  ],
}
