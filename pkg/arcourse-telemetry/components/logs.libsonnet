local yaml = import '../../arcourse-ui/components/yaml.libsonnet';
local time = import '../time/main.libsonnet';

local defaultColors = {
  fatal: '#8a3a3a',
  critical: '#8a3a3a',
  'error': '#a35454',
  warn: '#b0902f',
  warning: '#b0902f',
  info: '#5a7a94',
  debug: '#7a7a7a',
  trace: '#6a6a6a',
};

local style = |||
  @scope (.logs) {
    :scope {
      font-family: monospace;
      display: flex;
      flex-direction: column;
      gap: 0.1em;
      min-width: 32em;
    }
    .log-entry {
      border-left: 0.25em solid var(--border-color);
      border-radius: 0.25em;
    }
    .log-row {
      display: flex;
      align-items: baseline;
      gap: 0.5em;
      padding: 0.1em 0.4em;
      list-style: none;
    }
    .log-row::-webkit-details-marker {
      display: none;
    }
    details.log-entry > summary.log-row {
      cursor: pointer;
    }
    details.log-entry > summary.log-row:hover {
      background-color: var(--container-low-color);
      border-radius: 0.25em;
    }
    .log-time {
      color: var(--primary-color);
      white-space: nowrap;
      opacity: 0.8;
    }
    .log-body {
      white-space: pre-wrap;
      word-break: break-all;
    }
    .log-detail {
      padding: 0 0.4em 0.3em;
    }
    .logs-empty {
      opacity: 0.6;
    }
  }
|||;

local logRow = {
  local r = self,
  record:: error 'LogRow requires record',
  colors:: {},
  timeFormat:: error 'LogRow requires timeFormat',
  local rec = r.record,
  local fields = std.get(rec, 'fields', {}),
  local expandable = std.length(fields) > 0,
  local color = std.get(r.colors, std.asciiLower(std.get(rec, 'severity', '')), null),
  local entryAttrs = { class: 'log-entry' } + (if color != null then { style: 'border-left-color: %s' % color } else {}),
  local rowChildren = [
    { element: 'span', attributes: { class: 'log-time' }, children: [time.format(rec.timestamp, r.timeFormat)] },
    { element: 'span', attributes: { class: 'log-body' }, children: [std.get(rec, 'body', '')] },
  ],
  html:
    if expandable then {
      element: 'details',
      attributes: entryAttrs,
      children: [
        { element: 'summary', attributes: { class: 'log-row' }, children: rowChildren },
        { element: 'div', attributes: { class: 'log-detail' }, children: [yaml { data:: fields }] },
      ],
    } else {
      element: 'div',
      attributes: entryAttrs,
      children: [
        { element: 'div', attributes: { class: 'log-row' }, children: rowChildren },
      ],
    },
};

{
  local c = self,
  records:: error 'Logs requires records',
  colors:: defaultColors,
  timeFormat:: '2006-01-02 15:04:05.000',
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'logs card' },
      children:
        if std.length(c.records) == 0 then
          [{ element: 'div', attributes: { class: 'logs-empty' }, children: ['No logs'] }]
        else
          [(logRow { record:: rec, colors:: c.colors, timeFormat:: c.timeFormat }).html for rec in c.records],
    },
  ],
}
