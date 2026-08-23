local a = import './main.libsonnet';
local linkspecs = import './linkspecs.libsonnet';

local mockRoot = {
  pagerduty: {
    incidents: { id(v): { _node: true, kind: 'incident', id: v } },
    services: { id(v): { _node: true, kind: 'service', id: v } },
    users: { id(v): { _node: true, kind: 'user', id: v } },
  },
};

local pagerduty = { const: 'pagerduty' };

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
        local rows = t.html[1].children[1].children;
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
        local row = t.html[1].children[1].children[0];
        local cell = row.children[0].children[0].html;
        { element: cell.element, text: cell.children[0] },
      expected: { element: 'span', text: 'alpha' },
    },
    {
      name: 'a.table.view reads items and columns from the nested table field, not top-level itemsPath/columns',
      input:: function()
        local node = a.table.view {
          data: { addons: [{ id: 'a1', name: 'Alpha' }, { id: 'a2', name: 'Beta' }] },
          table: { at: ['addons'], columns: [{ label: 'Name', path: ['name'] }] },
        };
        local rows = node._view.fragment.html[1].children[1].children;
        { rowTexts: [row.children[0].children[0].html.children[0] for row in rows] },
      expected: { rowTexts: ['Alpha', 'Beta'] },
    },
    {
      name: 'empty linkSpecs yields no links',
      input:: function()
        linkspecs.buildLinks({ data: {} }, []),
      expected: {},
    },
    {
      name: 'root-anchored link resolves a param-sourced value under a const key, service taken from the front of value',
      input:: function()
        local node = {
          data: { id: 'inc_1', service_id: 'svc_1' },
        };
        linkspecs.buildLinks(node, [
          { at: [], keys: [{ const: 'service' }], value: [pagerduty, { const: 'services' }, { param: 'id', path: ['service_id'] }] },
        ], mockRoot),
      expected: {
        service: { _node: true, kind: 'service', id: 'svc_1' },
      },
    },
    {
      name: 'origin-sourced value reads the param from the node itself, not from data',
      input:: function()
        local node = {
          id: 'acc_1',
          data: { id: 'acc_1', name: 'Acme' },
        };
        linkspecs.buildLinks(node, [
          { at: [], keys: [{ const: 'origin' }], value: [pagerduty, { const: 'incidents' }, { origin: 'id' }] },
        ], mockRoot),
      expected: {
        origin: { _node: true, kind: 'incident', id: 'acc_1' },
      },
    },
    {
      name: 'a context-param origin segment resolves through a routed root, same as a path-param origin does',
      input:: function()
        local rootWithRegion = {
          acme: {
            region(v):: { services: { id(v2):: { _node: true, kind: 'service', region: v, id: v2 } } },
          },
        };
        local node = {
          region: 'eu',
          data: { id: 'acc_1', service_id: 'svc_1' },
        };
        local acme = { const: 'acme' };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'service' }],
            value: [acme, { origin: 'region' }, { const: 'services' }, { param: 'id', path: ['service_id'] }],
          },
        ], rootWithRegion),
      expected: {
        service: { _node: true, kind: 'service', region: 'eu', id: 'svc_1' },
      },
    },
    {
      name: 'array-crossing link folds every item into one nested bucket keyed by a relative path',
      input:: function()
        local node = {
          data: {
            members: [
              { user_id: 'u1', role: 'admin' },
              { user_id: 'u2', role: 'member' },
            ],
          },
        };
        linkspecs.buildLinks(node, [
          {
            at: ['members'],
            keys: [{ const: 'members' }, { path: ['user_id'] }],
            value: [pagerduty, { const: 'users' }, { param: 'id', path: ['user_id'] }],
          },
        ], mockRoot),
      expected: {
        members: {
          u1: { _node: true, kind: 'user', id: 'u1' },
          u2: { _node: true, kind: 'user', id: 'u2' },
        },
      },
    },
    {
      name: 'array of scalar ids treats each element as its own id via an empty relative path',
      input:: function()
        local node = {
          data: { acknowledged_user_ids: ['u1', 'u2'] },
        };
        linkspecs.buildLinks(node, [
          {
            at: ['acknowledged_user_ids'],
            keys: [{ const: 'acknowledged users' }, { path: [] }],
            value: [pagerduty, { const: 'users' }, { param: 'id', path: [] }],
          },
        ], mockRoot),
      expected: {
        'acknowledged users': {
          u1: { _node: true, kind: 'user', id: 'u1' },
          u2: { _node: true, kind: 'user', id: 'u2' },
        },
      },
    },
    {
      name: 'an anchor that is itself an array yields one link per item, as for a top-level list response',
      input:: function()
        local node = {
          data: [
            { user_id: 'u1' },
            { user_id: 'u2' },
          ],
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ path: ['user_id'] }],
            value: [pagerduty, { const: 'users' }, { param: 'id', path: ['user_id'] }],
          },
        ], mockRoot),
      expected: {
        u1: { _node: true, kind: 'user', id: 'u1' },
        u2: { _node: true, kind: 'user', id: 'u2' },
      },
    },
    {
      name: 'an item missing a value-sourced field is skipped rather than linking to a null segment',
      input:: function()
        local node = {
          data: [
            { user_id: 'u1' },
            { role: 'orphan' },
          ],
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ path: ['user_id'] }],
            value: [pagerduty, { const: 'users' }, { param: 'id', path: ['user_id'] }],
          },
        ], mockRoot),
      expected: {
        u1: { _node: true, kind: 'user', id: 'u1' },
      },
    },
    {
      name: 'chained array crossings merge contributions from every branch into one flat bucket',
      input:: function()
        local node = {
          data: {
            rotations: [
              { events: [{ members: [{ user_id: 'u1' }] }] },
              { events: [{ members: [{ user_id: 'u1' }, { user_id: 'u2' }] }] },
            ],
          },
        };
        linkspecs.buildLinks(node, [
          {
            at: ['rotations', 'events', 'members'],
            keys: [{ const: 'member' }, { path: ['user_id'] }],
            value: [pagerduty, { const: 'users' }, { param: 'id', path: ['user_id'] }],
          },
        ], mockRoot),
      expected: {
        member: {
          u1: { _node: true, kind: 'user', id: 'u1' },
          u2: { _node: true, kind: 'user', id: 'u2' },
        },
      },
    },
    {
      name: 'a missing field along at contributes nothing rather than erroring, root is never forced',
      input:: function()
        local node = {
          data: { id: 'inc_1' },
        };
        linkspecs.buildLinks(node, [
          { at: ['does_not_exist'], keys: [{ const: 'x' }, { path: [] }], value: [pagerduty, { const: 'users' }, { param: 'id', path: [] }] },
        ]),
      expected: {},
    },
    {
      name: 'withLinkSpecs merged standalone defaults to no links without forcing root',
      input:: function()
        local node = linkspecs.withLinkSpecs { data: { id: 'x' } };
        node.links,
      expected: {},
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
