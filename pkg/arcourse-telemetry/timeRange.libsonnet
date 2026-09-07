local navScript = importstr 'time-range-nav.js';

{
  paramSpecs: [
    { name: 'from', type: 'string', default: 'now-1h' },
    { name: 'to', type: 'string', default: 'now' },
  ],
  nav: {
    local c = self,
    from:: error 'nav requires from',
    to:: error 'nav requires to',
    html: [
      { element: 'time-range-nav', attributes: { from: c.from, to: c.to } },
      { element: 'script', children: [{ html: navScript }] },
    ],
  },
}
