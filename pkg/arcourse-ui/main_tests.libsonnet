local a = import './main.libsonnet';

{
  output(input):: input(),
  tests: [
    {
      name: 'table rows are fully clickable when a rowLink is supplied',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ id: 'i1', name: 'alpha' }, { id: 'i2', name: 'beta' }],
          columns:: [{ label: 'Name', path: ['name'] }, { label: 'ID', path: ['id'] }],
          rowLink:: function(item) { _node: true, _queryPath: '/x/' + item.id },
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
      name: 'table cells wrap in a non-link span when no rowLink is supplied',
      input:: function()
        local c = import './components/main.libsonnet';
        local t = c.table {
          items:: [{ name: 'alpha' }],
          columns:: [{ label: 'Name', path: ['name'] }],
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
          columns:: [{ label: 'Name', path: ['name'] }],
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
          columns:: [{ label: 'Name', path: ['name'] }],
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
          columns:: [{ label: 'Name', path: ['name'] }],
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
      name: 'a non-node child recurses to render each reachable node as a slash-labeled link',
      input:: function()
        local node = a.list.node {
          arcourse: { _node: true, _queryPath: '/root/arcourse' },
          kubernetes: { contexts: { _node: true, _queryPath: '/root/kubernetes/contexts' } },
          form3: {},
        };
        [{ link: i.link, text: i.text } for i in node._view.fragment.items],
      expected: [
        { link: '/root/arcourse', text: 'arcourse' },
        { link: '/root/kubernetes/contexts', text: 'kubernetes/contexts' },
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
