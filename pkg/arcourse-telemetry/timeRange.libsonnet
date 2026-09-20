local navScript = importstr 'time-range-nav.js';

local element = {
  local c = self,
  from:: error 'element requires from',
  to:: error 'element requires to',
  resultFrom:: null,
  resultTo:: null,
  html: {
    element: 'time-range-nav',
    attributes: { from: c.from, to: c.to }
                + (if c.resultFrom != null then { 'result-from': std.toString(c.resultFrom) } else {})
                + (if c.resultTo != null then { 'result-to': std.toString(c.resultTo) } else {}),
  },
};

local script = { html: { element: 'script', children: [{ html: navScript }] } };

{
  paramSpecs: [
    { name: 'from', type: 'string', default: 'now-1h' },
    { name: 'to', type: 'string', default: 'now' },
  ],
  element: element,
  script: script,
  nav: {
    local c = self,
    from:: error 'nav requires from',
    to:: error 'nav requires to',
    resultFrom:: null,
    resultTo:: null,
    html: [
      (element { from:: c.from, to:: c.to, resultFrom:: c.resultFrom, resultTo:: c.resultTo }).html,
      script.html,
    ],
  },
}
