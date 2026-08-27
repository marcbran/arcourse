local arcourseKubernetes = import './main.libsonnet';

local manifestLiteral(expr) =
  if expr.__kind__ == 'LiteralString' then expr.value
  else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
  else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
  else error 'unexpected kind ' + expr.__kind__;

local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;

local nodes(groups) =
  unwrap(arcourseKubernetes.graph {
    manifest: false,
    data+: { groups: groups },
  }._view.jsonnet).elements;

local nodePath(entry) = [part.expr.value for part in entry.expr.elements[0].expr.elements];
local nodeView(entry) = entry.expr.elements[1].expr.left;
local nodeBody(entry) = entry.expr.elements[1].expr.right;
local nodeKind(entry) = [nodeView(entry).id, nodeView(entry).target.id, nodeView(entry).target.target.id];
local fieldNames(body) = [f.id for f in body.fields];
local field(body, name) = [f for f in body.fields if f.id == name][0].expr2;
local applyTargetChain(apply) = [apply.target.id, apply.target.target.id, apply.target.target.target.id];

{
  output(input):: input(),
  tests: [
    {
      name: 'exports graph package entrypoint',
      input:: function() std.objectFields(arcourseKubernetes),
      expected: ['graph'],
    },
    {
      name: 'empty groups yields only the contexts and $context scaffold nodes',
      input:: function()
        local entries = nodes([]);
        { paths: [nodePath(e) for e in entries] },
      expected: {
        paths: [['kubernetes', 'contexts'], ['kubernetes', '$context']],
      },
    },
    {
      name: 'contexts node uses a.list.node and computes per-context links',
      input:: function()
        local entries = nodes([]);
        local contexts = entries[0];
        {
          kind: nodeKind(contexts),
          fieldNames: fieldNames(nodeBody(contexts)),
        },
      expected: {
        kind: ['node', 'list', 'a'],
        fieldNames: ['data', 'links'],
      },
    },
    {
      name: 'a cluster-scoped resource with list and get verbs generates a list node (a.list.node, no columns) and a resource detail node',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: false, verbs: ['list', 'get'], version: 'v1' };
        local entries = nodes([{ group: '', resources: [resource] }]);
        {
          paths: [nodePath(e) for e in entries[2:]],
          listKind: nodeKind(entries[2]),
          detailKind: nodeKind(entries[3]),
        },
      expected: {
        paths: [['kubernetes', '$context', 'widgets'], ['kubernetes', '$context', '$widget']],
        listKind: ['node', 'list', 'a'],
        detailKind: ['node', 'resource', 'a'],
      },
    },
    {
      name: 'a cluster-scoped resource list and detail node both fetch data through kubernetes.neat.get',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: false, verbs: ['list', 'get'], version: 'v1' };
        local entries = nodes([{ group: '', resources: [resource] }]);
        {
          listDataChain: applyTargetChain(field(nodeBody(entries[2]), 'data')),
          detailDataChain: applyTargetChain(field(nodeBody(entries[3]), 'data')),
        },
      expected: {
        listDataChain: ['get', 'neat', 'kubernetes'],
        detailDataChain: ['get', 'neat', 'kubernetes'],
      },
    },
    {
      name: 'a resource with columns generates a table node instead of a list node',
      input:: function()
        local resource = {
          name: 'widgets',
          kind: 'Widget',
          namespaced: false,
          verbs: ['list'],
          version: 'v1',
          columns: [{ label: 'Name', path: ['metadata', 'name'] }],
        };
        local entries = nodes([{ group: '', resources: [resource] }]);
        local body = nodeBody(entries[2]);
        {
          kind: nodeKind(entries[2]),
          fieldNames: fieldNames(body),
          columnLabels: [manifestLiteral(field(col.expr, 'label')) for col in field(field(body, 'table'), 'columns').elements],
        },
      expected: {
        kind: ['node', 'table', 'a'],
        fieldNames: ['data', 'linkSpecs', 'table'],
        columnLabels: ['Name'],
      },
    },
    {
      name: 'a resource with only the list verb generates no detail node',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: false, verbs: ['list'], version: 'v1' };
        local entries = nodes([{ group: '', resources: [resource] }]);
        { paths: [nodePath(e) for e in entries[2:]] },
      expected: {
        paths: [['kubernetes', '$context', 'widgets']],
      },
    },
    {
      name: 'a resource with only the get verb generates no list node',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: false, verbs: ['get'], version: 'v1' };
        local entries = nodes([{ group: '', resources: [resource] }]);
        { paths: [nodePath(e) for e in entries[2:]] },
      expected: {
        paths: [['kubernetes', '$context', '$widget']],
      },
    },
    {
      name: 'a namespaced resource generates an all-namespaces list, a per-namespace list, and a detail node, each with the right linkSpec value segments',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: true, verbs: ['list', 'get'], version: 'v1' };
        local entries = nodes([{ group: '', resources: [resource] }]);
        local allNs = entries[2];
        local oneNs = entries[3];
        local detail = entries[4];
        {
          paths: [nodePath(e) for e in [allNs, oneNs, detail]],
          allNsLinkValue: manifestLiteral(field(nodeBody(allNs), 'linkSpecs'))[0].value,
          oneNsLinkValue: manifestLiteral(field(nodeBody(oneNs), 'linkSpecs'))[0].value,
          detailKind: nodeKind(detail),
          allNsDataChain: applyTargetChain(field(nodeBody(allNs), 'data')),
          oneNsDataChain: applyTargetChain(field(nodeBody(oneNs), 'data')),
          detailDataChain: applyTargetChain(field(nodeBody(detail), 'data')),
        },
      expected: {
        paths: [
          ['kubernetes', '$context', 'widgets'],
          ['kubernetes', '$context', '$namespace', 'widgets'],
          ['kubernetes', '$context', '$namespace', '$widget'],
        ],
        allNsLinkValue: [
          { const: 'kubernetes' },
          { origin: 'context' },
          { param: 'namespace', path: ['metadata', 'namespace'] },
          { param: 'widget', path: ['metadata', 'name'] },
        ],
        oneNsLinkValue: [
          { const: 'kubernetes' },
          { origin: 'context' },
          { origin: 'namespace' },
          { param: 'widget', path: ['metadata', 'name'] },
        ],
        detailKind: ['node', 'resource', 'a'],
        allNsDataChain: ['get', 'neat', 'kubernetes'],
        oneNsDataChain: ['get', 'neat', 'kubernetes'],
        detailDataChain: ['get', 'neat', 'kubernetes'],
      },
    },
    {
      name: 'a non-empty group inserts empty scaffold nodes for the group context and (when namespaced resources exist) the group namespace',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: true, verbs: ['list'], version: 'v1' };
        local entries = nodes([{ group: 'acme.io', resources: [resource] }]);
        { paths: [nodePath(e) for e in entries[2:]] },
      expected: {
        paths: [
          ['kubernetes', '$context', 'acme.io'],
          ['kubernetes', '$context', '$namespace', 'acme.io'],
          ['kubernetes', '$context', 'acme.io', 'widgets'],
          ['kubernetes', '$context', '$namespace', 'acme.io', 'widgets'],
        ],
      },
    },
    {
      name: 'a bundled specs.json entry for a core resource derives a namespaced resource with list and get verbs from its OpenAPI paths',
      input:: function()
        local spec = {
          paths: {
            '/api/v1/namespaces/{namespace}/widgets': { get: { 'x-kubernetes-group-version-kind': { kind: 'Widget' } } },
            '/api/v1/namespaces/{namespace}/widgets/{name}': { get: {} },
          },
        };
        local entries = unwrap(arcourseKubernetes.graph {
          manifest: false,
          contexts: [],
          specs: { 'api/v1': spec },
        }._view.jsonnet).elements;
        {
          paths: [nodePath(e) for e in entries[2:]],
        },
      expected: {
        paths: [
          ['kubernetes', '$context', 'widgets'],
          ['kubernetes', '$context', '$namespace', 'widgets'],
          ['kubernetes', '$context', '$namespace', '$widget'],
        ],
      },
    },
    {
      name: 'a bundled specs.json entry for a group resource derives the group and version from its key',
      input:: function()
        local spec = {
          paths: {
            '/apis/acme.io/v1/widgets': { get: { 'x-kubernetes-group-version-kind': { kind: 'Widget' } } },
            '/apis/acme.io/v1/widgets/{name}': { get: {} },
          },
        };
        local entries = unwrap(arcourseKubernetes.graph {
          manifest: false,
          contexts: [],
          specs: { 'apis/acme.io/v1': spec },
        }._view.jsonnet).elements;
        { paths: [nodePath(e) for e in entries[2:]] },
      expected: {
        paths: [
          ['kubernetes', '$context', 'acme.io'],
          ['kubernetes', '$context', 'acme.io', 'widgets'],
          ['kubernetes', '$context', 'acme.io', '$widget'],
        ],
      },
    },
    {
      name: 'a group resource detail node gets an extra linkSpec from a matching inferred link, rewritten from the raw OpenAPI target path into the node-route convention',
      input:: function()
        local daemonset = { name: 'daemonsets', kind: 'DaemonSet', namespaced: true, verbs: ['list', 'get'], version: 'v1' };
        local controllerrevisions = { name: 'controllerrevisions', kind: 'ControllerRevision', namespaced: true, verbs: ['list', 'get'], version: 'v1' };
        local links = [
          {
            at: ['metadata', 'ownerReferences'],
            keys: [{ const: 'owner' }, { path: ['name'] }],
            sourcePath: '/apis/apps/v1/namespaces/{namespace}/controllerrevisions/{name}',
            value: [
              { const: 'apis' }, { const: 'apps' }, { const: 'v1' }, { const: 'namespaces' }, { origin: 'namespace' },
              { const: 'daemonsets' }, { param: 'name', path: ['name'] },
            ],
          },
        ];
        local entries = nodes([{ group: 'apps', resources: [daemonset, controllerrevisions], links: links }]);
        local detail = [e for e in entries if nodePath(e) == ['kubernetes', '$context', '$namespace', 'apps', '$controllerrevision']][0];
        local body = nodeBody(detail);
        {
          fieldNames: fieldNames(body),
          linkSpecs: manifestLiteral(field(body, 'linkSpecs')),
        },
      expected: {
        fieldNames: ['data', 'linkSpecs'],
        linkSpecs: [
          {
            at: ['metadata', 'ownerReferences'],
            keys: [{ const: 'owner' }, { path: ['name'] }],
            value: [
              { const: 'kubernetes' },
              { origin: 'context' },
              { origin: 'namespace' },
              { const: 'apps' },
              { param: 'daemonset', path: ['name'] },
            ],
          },
        ],
      },
    },
    {
      name: 'a core (groupless) resource detail node gets a linkSpec whose value has no group segment and drops the leading "api"/version pair instead of "apis"/group/version',
      input:: function()
        local pod = { name: 'pods', kind: 'Pod', namespaced: true, verbs: ['get'], version: 'v1' };
        local secret = { name: 'secrets', kind: 'Secret', namespaced: true, verbs: ['list', 'get'], version: 'v1' };
        local links = [
          {
            at: ['spec', 'volumes'],
            keys: [{ path: ['name'] }],
            sourcePath: '/api/v1/namespaces/{namespace}/pods/{name}',
            value: [
              { const: 'api' }, { const: 'v1' }, { const: 'namespaces' }, { origin: 'namespace' },
              { const: 'secrets' }, { param: 'name', path: ['secretName'] },
            ],
          },
        ];
        local entries = nodes([{ group: '', resources: [pod, secret], links: links }]);
        local detail = [e for e in entries if nodePath(e) == ['kubernetes', '$context', '$namespace', '$pod']][0];
        manifestLiteral(field(nodeBody(detail), 'linkSpecs'))[0].value,
      expected: [
        { const: 'kubernetes' },
        { origin: 'context' },
        { origin: 'namespace' },
        { param: 'secret', path: ['secretName'] },
      ],
    },
    {
      name: 'list nodes never get inferred linkSpecs (only their fixed self-link), and a detail-node link whose sourcePath does not match is not attached',
      input:: function()
        local resource = { name: 'widgets', kind: 'Widget', namespaced: false, verbs: ['list', 'get'], version: 'v1' };
        local links = [
          { at: ['items'], keys: [], sourcePath: '/apis/acme.io/v1/widgets', value: [] },
          { at: [], keys: [], sourcePath: '/apis/acme.io/v1/unrelated/{name}', value: [] },
        ];
        local entries = nodes([{ group: 'acme.io', resources: [resource], links: links }]);
        local list = [e for e in entries if nodePath(e) == ['kubernetes', '$context', 'acme.io', 'widgets']][0];
        local detail = [e for e in entries if nodePath(e) == ['kubernetes', '$context', 'acme.io', '$widget']][0];
        {
          listLinkSpecCount: std.length(manifestLiteral(field(nodeBody(list), 'linkSpecs'))),
          detailFieldNames: fieldNames(nodeBody(detail)),
        },
      expected: {
        listLinkSpecCount: 1,
        detailFieldNames: ['data'],
      },
    },
    {
      name: 'a link pointing directly at a Namespace object gets its param renamed to "namespace" (a well-known cross-group target), while a link to an unresolvable cross-group resource is dropped rather than emitting a broken param',
      input:: function()
        local resourcequota = { name: 'resourcequotas', kind: 'ResourceQuota', namespaced: true, verbs: ['list', 'get'], version: 'v1' };
        local links = [
          {
            at: [],
            keys: [{ path: ['metadata', 'name'] }],
            sourcePath: '/api/v1/namespaces/{namespace}/resourcequotas/{name}',
            value: [
              { const: 'api' }, { const: 'v1' }, { const: 'namespaces' }, { param: 'name', path: ['metadata', 'namespace'] },
            ],
          },
          {
            at: [],
            keys: [{ path: ['metadata', 'name'] }],
            sourcePath: '/api/v1/namespaces/{namespace}/resourcequotas/{name}',
            value: [
              { const: 'apis' }, { const: 'acme.io' }, { const: 'v1' }, { const: 'namespaces' }, { origin: 'namespace' },
              { const: 'widgets' }, { param: 'name', path: ['spec', 'widgetName'] },
            ],
          },
        ];
        local entries = nodes([{ group: '', resources: [resourcequota], links: links }]);
        local detail = [e for e in entries if nodePath(e) == ['kubernetes', '$context', '$namespace', '$resourcequota']][0];
        manifestLiteral(field(nodeBody(detail), 'linkSpecs')),
      expected: [
        {
          at: [],
          keys: [{ path: ['metadata', 'name'] }],
          value: [
            { const: 'kubernetes' },
            { origin: 'context' },
            { param: 'namespace', path: ['metadata', 'namespace'] },
          ],
        },
      ],
    },
  ],
}
