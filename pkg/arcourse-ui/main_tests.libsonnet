local a = import './main.libsonnet';

local resolveHtml(v) =
  if std.isArray(v) then
    std.flattenArrays([
      local r = resolveHtml(x);
      if std.isArray(r) then r else [r]
      for x in v
    ])
  else if std.isObject(v) && std.objectHas(v, 'html') && !std.objectHas(v, 'element') then resolveHtml(v.html)
  else if std.isObject(v) && std.objectHas(v, 'children') then v + { children: resolveHtml(v.children) }
  else v;

{
  output(input):: input(),
  tests: [
    {
      name: 'table rows are fully clickable when rowLinks are supplied',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ id: 'i1', name: 'alpha' }, { id: 'i2', name: 'beta' }],
          columns:: [{ key: 'name', label: 'Name' }, { key: 'id', label: 'ID' }],
          rowLinks:: [{ _node: true, _queryPath: '/x/i1' }, { _node: true, _queryPath: '/x/i2' }],
        };
        local rows = t.html[1].children[0].children[1].children;
        local cellsOf(row) = [td.children[0].html for td in row.children];
        {
          rowCount: std.length(rows),
          allCellsAreAnchors: std.all([
            std.all([std.type(cell) == 'object' && cell.element == 'a' for cell in cellsOf(row)])
            for row in rows
          ]),
          firstRowHrefs: [cell.attributes.href for cell in cellsOf(rows[0])],
          firstRowText: [cell.children[0] for cell in cellsOf(rows[0])],
          tdHasNoInlineStyle: std.all([!std.objectHas(td, 'attributes') for td in rows[0].children]),
          styleCoversCellFill: std.length(std.findSubstr('height: 100%', t.html[0].children[0])) > 0,
        },
      expected: {
        rowCount: 2,
        allCellsAreAnchors: true,
        firstRowHrefs: ['/x/i1', '/x/i1'],
        firstRowText: ['alpha', 'i1'],
        tdHasNoInlineStyle: true,
        styleCoversCellFill: true,
      },
    },
    {
      name: 'table cells wrap in a non-link span when no rowLinks are supplied',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ name: 'alpha' }],
          columns:: [{ key: 'name', label: 'Name' }],
        };
        local row = t.html[1].children[0].children[1].children[0];
        local cell = row.children[0].children[0].html;
        { element: cell.element, text: cell.children[0] },
      expected: { element: 'span', text: 'alpha' },
    },
    {
      name: 'table renders no pagination nav when pagination is absent',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ name: 'alpha' }],
          columns:: [{ key: 'name', label: 'Name' }],
        };
        { cardChildCount: std.length(t.html[1].children) },
      expected: { cardChildCount: 1 },
    },
    {
      name: 'table renders first/prev/next/last links uniformly when all four directions resolve',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ name: 'alpha' }],
          columns:: [{ key: 'name', label: 'Name' }],
          pagination:: {
            first: { _node: true, _queryPath: 'root/x?page=1' },
            prev: { _node: true, _queryPath: 'root/x?page=2' },
            next: { _node: true, _queryPath: 'root/x?page=4' },
            last: { _node: true, _queryPath: 'root/x?page=9' },
          },
        };
        local nav = t.html[1].children[1];
        {
          navClass: nav.attributes.class,
          linkElements: [c.element for c in nav.children],
          linkTexts: [c.children[0] for c in nav.children],
          linkHrefs: [c.attributes.href for c in nav.children],
        },
      expected: {
        navClass: 'table-pagination',
        linkElements: ['a', 'a', 'a', 'a'],
        linkTexts: ['«', '‹', '›', '»'],
        linkHrefs: ['root/x?page=1', 'root/x?page=2', 'root/x?page=4', 'root/x?page=9'],
      },
    },
    {
      name: 'table renders a disabled span for each direction that does not resolve',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ name: 'alpha' }],
          columns:: [{ key: 'name', label: 'Name' }],
          pagination:: {
            next: { _node: true, _queryPath: 'root/x?page=2' },
          },
        };
        local nav = t.html[1].children[1];
        {
          elements: [c.element for c in nav.children],
          disabledFlags: [std.get(c.attributes, 'class', null) == 'disabled' for c in nav.children],
        },
      expected: {
        elements: ['span', 'span', 'a', 'span'],
        disabledFlags: [true, true, false, true],
      },
    },
    {
      name: 'a.table.view wires pagination from $.links.pagination into the table component',
      input:: function()
        local node = a.table.view {
          data: { items: [{ name: 'alpha' }] },
          table: { columns: [{ label: 'Name', path: ['name'] }] },
          links: { pagination: { next: { _node: true, _queryPath: 'root/x?page=2' } } },
        };
        local nav = node._view.fragment.html[1].children[1];
        { nextHref: nav.children[2].attributes.href },
      expected: { nextHref: 'root/x?page=2' },
    },
    {
      name: 'a.table.view without links renders no pagination nav',
      input:: function()
        local node = a.table.node {
          data: { items: [{ name: 'alpha' }] },
          table: { columns: [{ label: 'Name', path: ['name'] }] },
        };
        { cardChildCount: std.length(node._view.fragment.html[1].children) },
      expected: { cardChildCount: 1 },
    },
    {
      name: 'a.table.view reads items and columns from the nested table field, not top-level itemsPath/columns',
      input:: function()
        local node = a.table.view {
          data: { addons: [{ id: 'a1', name: 'Alpha' }, { id: 'a2', name: 'Beta' }] },
          table: { at: ['addons'], columns: [{ label: 'Name', path: ['name'] }] },
        };
        local rows = node._view.fragment.html[1].children[0].children[1].children;
        { rowTexts: [row.children[0].children[0].html.children[0] for row in rows] },
      expected: { rowTexts: ['Alpha', 'Beta'] },
    },
    {
      name: 'a.table.node projects data items into a flat items list keyed by lowerCamelCase label or explicit key, computing value columns and dropping missing fields',
      input:: function()
        local node = a.table.node {
          data: {
            kind: 'PodList',
            items: [
              { metadata: { name: 'api' }, status: { podIP: '10.0.0.1', containerStatuses: [{ ready: true }, { ready: false }] } },
              { metadata: { name: 'db' }, spec: { nodeName: 'node-a' }, status: { containerStatuses: [{ ready: true }] } },
            ],
          },
          table: {
            at: ['items'],
            columns: [
              { label: 'Name', path: ['metadata', 'name'] },
              {
                label: 'Ready',
                paths: [['status', 'containerStatuses']],
                value(item):: '%d/%d' % [std.length([s for s in item.status.containerStatuses if s.ready]), std.length(item.status.containerStatuses)],
              },
              { label: 'Pod IP', path: ['status', 'podIP'] },
              { key: 'host', label: 'Node', path: ['spec', 'nodeName'] },
            ],
          },
        };
        {
          items: node.items,
          dataVisible: std.objectHas(node, 'data'),
        },
      expected: {
        items: [
          { name: 'api', ready: '1/2', podIP: '10.0.0.1' },
          { name: 'db', ready: '1/1', host: 'node-a' },
        ],
        dataVisible: false,
      },
    },
    {
      name: 'column keys default to the label in lowerCamelCase, keeping the casing of later words',
      input:: function()
        local labels = ['Name', 'First seen', 'Resource Version', 'Pod IP', 'ID', 'CPU %', 'last-seen at'];
        local node = a.table.node {
          data: { items: [{}] },
          table: { columns: [{ label: label, value(item):: label } for label in labels] },
        };
        std.objectFields(node.items[0]),
      expected: std.sort(['name', 'firstSeen', 'resourceVersion', 'podIP', 'id', 'cpu', 'lastSeenAt']),
    },
    {
      name: 'a.table.node projects scalar items with an empty column path',
      input:: function()
        local node = a.table.node {
          data: ['alpha', 'beta'],
          table: { at: [], columns: [{ label: 'Value', path: [] }] },
        };
        node.items,
      expected: [{ value: 'alpha' }, { value: 'beta' }],
    },
    {
      name: 'a.table.node resolves links from data fields that are not columns',
      input:: function()
        local node = a.table.node {
          data: { items: [{ id: 'P1', name: 'alpha' }, { id: 'P2', name: 'beta' }] },
          linkSpecs:: [{
            at: ['items'],
            keys: [{ path: ['id'] }],
            value: { scheme: 'https', host: [{ const: 'svc.example.com' }], path: [{ path: ['id'] }] },
          }],
          table: { at: ['items'], columns: [{ label: 'Name', path: ['name'] }] },
        };
        { items: node.items, links: node.links },
      expected: {
        items: [{ name: 'alpha' }, { name: 'beta' }],
        links: { P1: 'https://svc.example.com/P1', P2: 'https://svc.example.com/P2' },
      },
    },
    {
      name: 'a URL link opens in a new tab with rel=noopener, unlike a node-backed link',
      input:: function()
        local c = import './components/main.libsonnet';
        local l = c.list {
          items:: [
            { link: 'https://docs.example.com/x', text: 'externalLink', external: true },
            { link: 'kubernetes/ctx/ns', text: 'internalLink' },
          ],
        };
        local anchors = l.html[1].children[0].children[0].html.children;
        [
          {
            href: li.children[0].attributes.href,
            target: std.get(li.children[0].attributes, 'target', null),
            rel: std.get(li.children[0].attributes, 'rel', null),
          }
          for li in anchors
        ],
      expected: [
        { href: 'https://docs.example.com/x', target: '_blank', rel: 'noopener noreferrer' },
        { href: 'kubernetes/ctx/ns', target: null, rel: null },
      ],
    },
    {
      name: 'a top-level URL link renders as an item alongside node-backed links',
      input:: function()
        local node = a.resource.node {
          data: { id: 'x' },
          linkSpecs:: [
            {
              at: [],
              keys: [{ const: 'externalLink' }],
              value: { scheme: 'https', host: [{ const: 'docs.example.com' }], path: [{ const: 'x' }] },
            },
          ],
        };
        [{ link: i.link, text: i.text } for i in node._view.fragment.items],
      expected: [{ link: 'https://docs.example.com/x', text: 'externalLink' }],
    },
    {
      name: 'a grouped URL link renders under its titled group alongside node-backed groups',
      input:: function()
        local node = a.resource.node {
          data: { rules: [{ host: 'a.example.com' }] },
          linkSpecs:: [
            {
              at: ['rules'],
              keys: [{ const: 'ingress' }, { path: ['host'] }],
              value: { scheme: 'https', host: [{ path: ['host'] }] },
            },
          ],
        };
        [{ title: g.title, items: [{ link: i.link, text: i.text } for i in g.items] } for g in node._view.fragment.groups],
      expected: [
        { title: 'ingress', items: [{ link: 'https://a.example.com', text: 'a.example.com' }] },
      ],
    },
    {
      name: 'a non-node child renders as a titled group of its reachable nodes, deeper nodes slash-labeled within the group, empty ones omitted',
      input:: function()
        local node = a.list.node {
          arcourse: { _node: true, _queryPath: '/root/arcourse' },
          kubernetes: {
            contexts: { _node: true, _queryPath: '/root/kubernetes/contexts' },
            nested: { deep: { _node: true, _queryPath: '/root/kubernetes/nested/deep' } },
          },
          form3: {},
        };
        {
          items: [{ link: i.link, text: i.text } for i in node._view.fragment.items],
          groups: [{ title: g.title, items: [{ link: i.link, text: i.text } for i in g.items] } for g in node._view.fragment.groups],
        },
      expected: {
        items: [{ link: '/root/arcourse', text: 'arcourse' }],
        groups: [{
          title: 'kubernetes',
          items: [
            { link: '/root/kubernetes/contexts', text: 'contexts' },
            { link: '/root/kubernetes/nested/deep', text: 'nested/deep' },
          ],
        }],
      },
    },
    {
      name: 'a node reachable through a links group is not repeated in a child group',
      input:: function()
        local deployments = { _node: true, _queryPath: '/root/apps/deployments' };
        local node = a.list.node {
          apps: { deployments: deployments, statefulsets: { _node: true, _queryPath: '/root/apps/statefulsets' } },
          links: { curated: { deployments: deployments } },
        };
        [{ title: g.title, items: [i.text for i in g.items] } for g in node._view.fragment.groups],
      expected: [
        { title: 'curated', items: ['deployments'] },
        { title: 'apps', items: ['statefulsets'] },
      ],
    },
    {
      name: 'scalar param fields on a node do not render as links',
      input:: function()
        local node = a.table.node {
          context: 'my-context',
          namespace: 'my-namespace',
          configmap: 'my-configmap',
          data: { items: [] },
        };
        [{ link: i.link, text: i.text } for i in node._view.fragment.items],
      expected: [],
    },
    {
      name: 'list.columns splits the cards in order into that many columns balanced by line count',
      input:: function()
        local link(name) = { _node: true, _queryPath: '/root/' + name };
        local node = a.list.node {
          list:: { columns: 2 },
          core: link('core'),
          a: { x1: link('a/x1'), x2: link('a/x2'), x3: link('a/x3') },
          b: { y1: link('b/y1') },
          c: { z1: link('c/z1'), z2: link('c/z2') },
        };
        local aside = node._view.fragment.html[1];
        local cardTitle(nav) = if std.get(nav.children[0], 'element', null) == 'strong' then nav.children[0].children[0] else 'items';
        {
          class: aside.attributes.class,
          columns: [[cardTitle(nav) for nav in column.children] for column in aside.children],
        },
      expected: {
        class: 'list columns',
        columns: [['items', 'a'], ['b', 'c']],
      },
    },
    {
      name: 'list.groupOrder sorts the group cards by their position in it and keeps unlisted groups after them in their original order',
      input:: function()
        local link(name) = { _node: true, _queryPath: '/root/' + name };
        local node = a.list.node {
          list:: { groupOrder: ['traefik.io', 'apps', 'missing'] },
          'apps': { deployments: link('apps/deployments') },
          'hub.traefik.io': { aiservices: link('hub.traefik.io/aiservices') },
          'cilium.io': { ciliumnodes: link('cilium.io/ciliumnodes') },
          'traefik.io': { middlewares: link('traefik.io/middlewares') },
        };
        [group.title for group in node._view.fragment.groups],
      expected: ['traefik.io', 'apps', 'cilium.io', 'hub.traefik.io'],
    },
    {
      name: 'list.nodeGroups moves the listed node neighbors out of the items into a group card in the listed order, sorted by list.groupOrder',
      input:: function()
        local link(name) = { _node: true, _queryPath: '/root/' + name };
        local node = a.list.node {
          list:: {
            groupOrder: ['apps', 'remaining groups'],
            nodeGroups: { 'remaining groups': ['traefik.io', 'cilium.io', 'missing'] },
          },
          pods: link('pods'),
          'cilium.io': link('cilium.io'),
          'traefik.io': link('traefik.io'),
          apps: { deployments: link('apps/deployments') },
        };
        {
          items: [item.text for item in node._view.fragment.items],
          groups: [{ title: group.title, items: [item.text for item in group.items] } for group in node._view.fragment.groups],
        },
      expected: {
        items: ['pods'],
        groups: [
          { title: 'apps', items: ['deployments'] },
          { title: 'remaining groups', items: ['traefik.io', 'cilium.io'] },
        ],
      },
    },
    {
      name: 'list.hiddenItems drops the listed items of a card keyed by card title, the untitled card at the empty key, and drops cards left empty',
      input:: function()
        local link(name) = { _node: true, _queryPath: '/root/' + name };
        local node = a.list.node {
          list:: { hiddenItems: { '': ['services'], apps: ['replicasets'], metrics: ['pods/phase'], batch: ['jobs'] } },
          pods: link('pods'),
          services: link('services'),
          apps: { deployments: link('apps/deployments'), replicasets: link('apps/replicasets') },
          metrics: { pods: { cpu: link('metrics/pods/cpu'), phase: link('metrics/pods/phase') } },
          batch: { jobs: link('batch/jobs') },
        };
        {
          items: [item.text for item in node._view.fragment.items],
          groups: [{ title: group.title, items: [item.text for item in group.items] } for group in node._view.fragment.groups],
        },
      expected: {
        items: ['pods'],
        groups: [
          { title: 'apps', items: ['deployments'] },
          { title: 'metrics', items: ['pods/cpu'] },
        ],
      },
    },
    {
      name: 'a.resource.node keeps links beside the content by default and puts the content first when resource.stacked is set',
      input:: function()
        local base = a.resource.node {
          data: { id: 'x' },
          child: { _node: true, _queryPath: '/root/x/child' },
        };
        local layout(node) =
          local div = node._view.fragment.html[1];
          { class: div.attributes.class, first: div.children[0].html[1].attributes.class };
        {
          default: layout(base),
          stacked: layout(base { resource:: { stacked: true } }),
        },
      expected: {
        default: { class: 'resource', first: 'list' },
        stacked: { class: 'resource stacked', first: 'yaml card' },
      },
    },
    {
      name: 'action without params renders only the apply form and no script',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          summary:: 'Restart',
          action:: { plugin: 'test', name: 'echo', data: {} },
        };
        local card = resolveHtml(t.html)[std.length(resolveHtml(t.html)) - 1];
        local buttons = card.children[std.length(card.children) - 1];
        {
          htmlCount: std.length(resolveHtml(t.html)),
          element: card.element,
          summary: card.children[0].children[0],
          buttons: [b.attributes.class for b in buttons.children],
          evaluationId: buttons.children[0].children[0].attributes.value,
        },
      expected: {
        htmlCount: 2,
        element: 'action-card',
        summary: 'Restart',
        buttons: ['apply'],
        evaluationId: 'e1',
      },
    },
    {
      name: 'action with a missing param renders a hint, a plan button and no apply form',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: {},
          action:: { issues: [{ param: 'replicas', message: 'is required' }] },
        };
        local card = resolveHtml(t.html)[2];
        local form = card.children[0];
        local buttons = card.children[1];
        {
          hasScript: resolveHtml(t.html)[1].element == 'script',
          formId: form.attributes.id,
          formMethod: form.attributes.method,
          input: form.children[0].children[1].attributes,
          issue: { class: form.children[1].attributes.class, text: form.children[1].children[0] },
          buttons: [b.children[0] for b in buttons.children],
          planTarget: buttons.children[0].attributes.form,
        },
      expected: {
        hasScript: true,
        formId: 'action-params',
        formMethod: 'get',
        input: { type: 'number', step: 'any', name: 'replicas', value: null },
        issue: { class: 'issue hint', text: 'is required' },
        buttons: ['Plan'],
        planTarget: 'action-params',
      },
    },
    {
      name: 'action with an initial value prefills the input and hides the required hint',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: {},
          initialValues:: { replicas: 2 },
          action:: { issues: [{ param: 'replicas', message: 'is required' }] },
        };
        local card = resolveHtml(t.html)[2];
        local form = card.children[0];
        {
          value: form.children[0].children[1].attributes.value,
          formChildren: std.length(form.children),
          buttons: [b.children[0] for b in card.children[1].children],
        },
      expected: { value: '2', formChildren: 1, buttons: ['Plan'] },
    },
    {
      name: 'action with a bound param ignores the initial value',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: { replicas: -1 },
          initialValues:: { replicas: 2 },
          action:: { issues: [{ param: 'replicas', message: 'must be at least 0' }] },
        };
        local form = resolveHtml(t.html)[2].children[0];
        {
          value: form.children[0].children[1].attributes.value,
          issueClass: form.children[1].attributes.class,
        },
      expected: { value: '-1', issueClass: 'issue' },
    },
    {
      name: 'action with an invalid present param renders an error and no apply form',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: { replicas: -1 },
          action:: { issues: [{ param: 'replicas', message: 'must be at least 0' }] },
        };
        local form = resolveHtml(t.html)[2].children[0];
        {
          value: form.children[0].children[1].attributes.value,
          issueClass: form.children[1].attributes.class,
          buttonCount: std.length(resolveHtml(t.html)[2].children[1].children),
        },
      expected: { value: '-1', issueClass: 'issue', buttonCount: 1 },
    },
    {
      name: 'action with a bound param prefills the input and renders plan and apply',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e2',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: { replicas: 3 },
          action:: { plugin: 'kubernetes', name: 'patch', data: {} },
        };
        local card = resolveHtml(t.html)[2];
        local buttons = card.children[1];
        {
          value: card.children[0].children[0].children[1].attributes.value,
          plan: buttons.children[0].children[0],
          applyClass: buttons.children[1].attributes.class,
          evaluationId: buttons.children[1].children[0].attributes.value,
        },
      expected: { value: '3', plan: 'Plan', applyClass: 'apply', evaluationId: 'e2' },
    },
    {
      name: 'action renders form-level issues and issues for unknown params above the form',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [{ name: 'replicas', type: 'number', default: null }],
          params:: { replicas: 3 },
          action:: { issues: [{ message: 'deployment is paused' }, { param: 'other', message: 'is wrong' }] },
        };
        local card = resolveHtml(t.html)[2];
        [{ class: p.attributes.class, text: p.children[0] } for p in card.children[0:2]],
      expected: [
        { class: 'issue', text: 'deployment is paused' },
        { class: 'issue', text: 'other: is wrong' },
      ],
    },
    {
      name: 'action renders booleans as a select, strings as text and other types as hidden json',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.action {
          evaluationId:: 'e1',
          paramSpecs:: [
            { name: 'force', type: 'boolean', default: false },
            { name: 'reason', type: 'string', default: null },
            { name: 'tags', type: 'array', items: 'string', default: null },
          ],
          params:: { force: false, tags: ['a'] },
          action:: { plugin: 'test', name: 'echo', data: {} },
        };
        local form = resolveHtml(t.html)[2].children[0];
        local select = form.children[0].children[1];
        {
          options: [{ value: o.attributes.value, selected: o.attributes.selected } for o in select.children],
          text: form.children[1].children[1].attributes,
          hidden: form.children[2].attributes,
        },
      expected: {
        options: [
          { value: '', selected: false },
          { value: 'true', selected: false },
          { value: 'false', selected: true },
        ],
        text: { type: 'text', name: 'reason', value: null },
        hidden: { type: 'hidden', name: 'tags', value: '["a"]' },
      },
    },
    {
      name: 'a.resource.node without linkSpecs exposes an empty links object',
      input:: function()
        local node = a.resource.node {
          data: { id: 'x' },
        };
        node.links,
      expected: {},
    },
  ],
}
