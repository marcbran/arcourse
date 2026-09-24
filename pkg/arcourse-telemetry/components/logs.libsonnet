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
      align-items: flex-start;
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
    :scope.logs-tabular .log-header,
    :scope.logs-tabular .log-row {
      display: grid;
      gap: 0 0.75em;
      align-items: baseline;
    }
    :scope.logs-tabular .log-header {
      color: var(--primary-color);
      font-weight: bold;
      padding: 0.1em 0.4em;
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
    a.log-time {
      text-decoration: none;
    }
    a.log-time:hover {
      text-decoration: underline;
    }
    .log-body {
      white-space: pre-wrap;
      word-break: break-all;
    }
    .log-cell {
      white-space: nowrap;
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
  link:: null,
  columns:: [],
  template:: null,
  local rec = r.record,
  local fields = std.get(rec, 'fields', {}),
  local expandable = std.length(fields) > 0,
  local tabular = std.length(r.columns) > 0,
  local color = std.get(r.colors, std.asciiLower(std.get(rec, 'severity', '')), null),
  local timeText = time.format(rec.timestamp, r.timeFormat),
  local timeEl =
    if r.link != null then { element: 'a', attributes: { class: 'log-time', href: r.link }, children: [timeText] }
    else { element: 'span', attributes: { class: 'log-time' }, children: [timeText] },
  local cells =
    if tabular then
      [timeEl] + [
        { element: 'span', attributes: { class: 'log-cell' }, children: [std.toString(std.get(fields, col, ''))] }
        for col in r.columns
      ]
    else
      [timeEl, { element: 'span', attributes: { class: 'log-body' }, children: [std.get(rec, 'body', '')] }],
  local rowAttrs = { class: 'log-row' } + (if tabular then { style: 'grid-template-columns: %s' % r.template } else {}),
  local entryAttrs = { class: 'log-entry' } + (if color != null then { style: 'border-left-color: %s' % color } else {}),
  html:
    if expandable then {
      element: 'details',
      attributes: entryAttrs,
      children: [
        { element: 'summary', attributes: rowAttrs, children: cells },
        { element: 'div', attributes: { class: 'log-detail' }, children: [yaml { data:: fields }] },
      ],
    } else {
      element: 'div',
      attributes: entryAttrs,
      children: [
        { element: 'div', attributes: rowAttrs, children: cells },
      ],
    },
};

{
  local c = self,
  records:: error 'Logs requires records',
  colors:: defaultColors,
  timeFormat:: '2006-01-02 15:04:05.000',
  links:: {},
  columns:: [],
  local tabular = std.length(c.columns) > 0,
  local fieldWidth(col) = std.foldl(
    function(m, rec) std.max(m, std.length(std.toString(std.get(std.get(rec, 'fields', {}), col, '')))),
    c.records,
    std.length(col),
  ),
  local template =
    if tabular then std.join(' ', ['%dch' % std.length(c.timeFormat)] + ['%dch' % fieldWidth(col) for col in c.columns])
    else null,
  html: [
    { element: 'style', children: [style] },
    {
      element: 'div',
      attributes: { class: 'logs card' + (if tabular then ' logs-tabular' else '') },
      children:
        (if tabular then [{
           element: 'div',
           attributes: { class: 'log-header', style: 'grid-template-columns: %s' % template },
           children: [{ element: 'span', children: ['time'] }] + [{ element: 'span', children: [col] } for col in c.columns],
         }] else [])
        + (
          if std.length(c.records) == 0 then
            [{ element: 'div', attributes: { class: 'logs-empty' }, children: ['No logs'] }]
          else
            [
              (logRow {
                 record:: rec,
                 colors:: c.colors,
                 timeFormat:: c.timeFormat,
                 link:: std.get(c.links, std.get(rec, 'id', ''), null),
                 columns:: c.columns,
                 template:: template,
               }).html
              for rec in c.records
            ]
        ),
    },
  ],
}
