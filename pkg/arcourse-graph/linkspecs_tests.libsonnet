local linkspecs = import './linkspecs.libsonnet';

local mockRoot = {
  tracker: {
    incidents: { id(v): { _node: true, kind: 'incident', id: v } },
    services: { id(v): { _node: true, kind: 'service', id: v } },
    users: { id(v): { _node: true, kind: 'user', id: v } },
  },
};

local tracker = { const: 'tracker' };

{
  output(input):: input(),
  tests: [
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
          { at: [], keys: [{ const: 'service' }], value: [tracker, { const: 'services' }, { param: 'id', path: ['service_id'] }] },
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
          { at: [], keys: [{ const: 'origin' }], value: [tracker, { const: 'incidents' }, { origin: 'id' }] },
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
            value: [tracker, { const: 'users' }, { param: 'id', path: ['user_id'] }],
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
            value: [tracker, { const: 'users' }, { param: 'id', path: [] }],
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
            value: [tracker, { const: 'users' }, { param: 'id', path: ['user_id'] }],
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
            value: [tracker, { const: 'users' }, { param: 'id', path: ['user_id'] }],
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
            value: [tracker, { const: 'users' }, { param: 'id', path: ['user_id'] }],
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
          { at: ['does_not_exist'], keys: [{ const: 'x' }, { path: [] }], value: [tracker, { const: 'users' }, { param: 'id', path: [] }] },
        ]),
      expected: {},
    },
    {
      name: 'a bare path+transform segment resolves a computed property-access key from the item, no param call involved',
      input:: function()
        local root = { acme: { apps: { services: { id(v): { _node: true, kind: 'service', group: 'apps', id: v } } } } };
        local node = {
          data: { source: 'apps/v1', service_id: 'svc_1' },
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'service' }],
            value: [
              { const: 'acme' },
              { path: ['source'], transform: function(v) std.split(v, '/')[0] },
              { const: 'services' },
              { param: 'id', path: ['service_id'] },
            ],
          },
        ], root),
      expected: {
        service: { _node: true, kind: 'service', group: 'apps', id: 'svc_1' },
      },
    },
    {
      name: 'a param segment with a nested path+transform spec resolves the method name from the item, distinct from the arg path',
      input:: function()
        local root = { acme: { replicaset(v): { _node: true, kind: 'ReplicaSet', name: v }, daemonset(v): { _node: true, kind: 'DaemonSet', name: v } } };
        local node = {
          data: { owner: { kind: 'ReplicaSet', name: 'my-rs' } },
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'owner' }],
            value: [
              { const: 'acme' },
              { param: { path: ['owner', 'kind'], transform: std.asciiLower }, path: ['owner', 'name'] },
            ],
          },
        ], root),
      expected: {
        owner: { _node: true, kind: 'ReplicaSet', name: 'my-rs' },
      },
    },
    {
      name: 'a literal spec builds a URL from scheme and host segments, root is never forced',
      input:: function()
        local node = {
          data: { host: 'my-app.example.com' },
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'externalLink' }],
            value: { scheme: 'https', host: [{ path: ['host'] }] },
          },
        ]),
      expected: {
        externalLink: 'https://my-app.example.com',
      },
    },
    {
      name: 'a literal spec reads an origin segment into the query string, not from item data',
      input:: function()
        local node = {
          cluster: 'eu-west',
          data: { host: 'my-app.example.com' },
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'externalLink' }],
            value: {
              scheme: 'https',
              host: [{ path: ['host'] }],
              query: { cluster: [{ origin: 'cluster' }] },
            },
          },
        ]),
      expected: {
        externalLink: 'https://my-app.example.com?cluster=eu-west',
      },
    },
    {
      name: 'a literal spec crossing an array yields one URL per item, keyed like any other spec',
      input:: function()
        local node = {
          data: {
            rules: [{ host: 'a.example.com' }, { host: 'b.example.com' }],
          },
        };
        linkspecs.buildLinks(node, [
          {
            at: ['rules'],
            keys: [{ const: 'ingress' }, { path: ['host'] }],
            value: { scheme: 'https', host: [{ path: ['host'] }] },
          },
        ]),
      expected: {
        ingress: {
          'a.example.com': 'https://a.example.com',
          'b.example.com': 'https://b.example.com',
        },
      },
    },
    {
      name: 'a literal spec percent-encodes path segments and query values, unlike host which passes through the raw value',
      input:: function()
        local node = {
          data: { section: 'a b/c', search: 'x&y=z' },
        };
        linkspecs.buildLinks(node, [
          {
            at: [],
            keys: [{ const: 'externalLink' }],
            value: {
              scheme: 'https',
              host: [{ const: 'docs.example.com:8443' }],
              path: [{ path: ['section'] }],
              query: { q: [{ path: ['search'] }] },
            },
          },
        ]),
      expected: {
        externalLink: 'https://docs.example.com:8443/a%20b%2Fc?q=x%26y%3Dz',
      },
    },
    {
      name: 'withLinkSpecs merged standalone defaults to no links without forcing root',
      input:: function()
        local node = linkspecs.withLinkSpecs { data: { id: 'x' } };
        node.links,
      expected: {},
    },
  ],
}
