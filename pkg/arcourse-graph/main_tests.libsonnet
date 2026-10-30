local g = import './main.libsonnet';

local node(input) = g.node(input.path, std.get(input, 'body', {}));
local graph(input) = g.graph(input.nodeSpecs, std.get(input, 'defaultView', {}));

local nodeTests = {
  name: 'node',
  output(input):: node(input),
  tests: [
    {
      name: 'exposes resolved path fields',
      input:: {
        path: ['kubernetes', '$context', 'pods'],
        body: { context: 'prod', kind: 'Pod' },
      },
      output(input)::
        local result = node(input);
        {
          node: result,
          hasPathTemplate: std.objectHasAll(result, '_pathTemplate'),
          hasVisiblePathTemplate: std.objectHas(result, '_pathTemplate'),
          pathTemplate: result._pathTemplate,
          queryPath: result._queryPath,
          vars: result._vars,
        },
      expected: {
        node: {
          _node: true,
          context: 'prod',
          kind: 'Pod',
        },
        hasPathTemplate: true,
        hasVisiblePathTemplate: false,
        pathTemplate: ['kubernetes', '$context', 'pods'],
        queryPath: '/root/kubernetes/context/prod/pods',
        vars: ['context'],
      },
    },
    {
      name: 'query path escapes variable values like url.PathEscape',
      input:: {
        path: ['kubernetes', '$context', 'pods'],
        body: { context: 'arn:aws:eks/prod cluster' },
      },
      output(input):: node(input)._queryPath,
      expected: '/root/kubernetes/context/arn:aws:eks%2Fprod%20cluster/pods',
    },
    {
      name: 'query path includes params that differ from their defaults',
      input:: {
        path: ['logs'],
        body: {
          _paramSpecs: [
            { name: 'from', type: 'string', default: 'now-1h' },
            { name: 'to', type: 'string', default: 'now' },
            { name: 'columns', type: 'array', items: 'string', default: [] },
            { name: 'filter', type: 'string' },
          ],
        },
      },
      output(input):: (node(input) { _params: { from: 'now-6h', to: 'now', columns: ['k8s/pod', 'msg'], filter: 'a b' } })._queryPath,
      expected: '/root/logs?columns=k8s%2Fpod&columns=msg&filter=a+b&from=now-6h',
    },
    {
      name: 'query path omits query when all params are defaults',
      input:: {
        path: ['logs'],
        body: {
          _paramSpecs: [{ name: 'from', type: 'string', default: 'now-1h' }],
          _params: { from: 'now-1h' },
        },
      },
      output(input):: node(input)._queryPath,
      expected: '/root/logs',
    },
    {
      name: 'query path follows params set on an extended node',
      input:: {
        path: ['items'],
        body: {
          _paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
          _params: { page: 1 },
        },
      },
      output(input):: (node(input) { _params+: { page: 3 } })._queryPath,
      expected: '/root/items?page=3',
    },
    {
      name: 'params default to spec defaults without being visible',
      input:: {
        path: ['items'],
        body: {
          _paramSpecs: [
            { name: 'page', type: 'number', default: 1 },
            { name: 'filter', type: 'string', default: null },
            { name: 'id', type: 'string' },
          ],
        },
      },
      output(input)::
        local result = node(input);
        { params: result._params, visible: std.objectHas(result, '_params') },
      expected: { params: { page: 1 }, visible: false },
    },
    {
      name: 'node without param specs has empty params',
      input:: { path: ['demo'] },
      output(input):: node(input)._params,
      expected: {},
    },
    {
      name: 'params set in a body layer count as defaults for the query path',
      input:: {
        path: ['items'],
        body: [
          { _paramSpecs: [{ name: 'page', type: 'number', default: 1 }, { name: 'filter', type: 'string', default: null }] },
          { _params+: { filter: 'active' } },
        ],
      },
      output(input)::
        local result = node(input);
        { params: result._params, queryPath: result._queryPath, extended: (result { _params+: { page: 2 } })._queryPath },
      expected: { params: { page: 1, filter: 'active' }, queryPath: '/root/items', extended: '/root/items?page=2' },
    },
    {
      name: 'omitting body yields synthetic-fields-only node',
      input:: {
        path: ['demo'],
      },
      expected: {
        _node: true,
      },
    },
    {
      name: 'array body merges layers in source order',
      input:: {
        path: ['demo'],
        body: [{ value: 'base' }, { value: 'first' }, { value: 'second', extra: true }],
      },
      expected: {
        _node: true,
        value: 'second',
        extra: true,
      },
    },
    {
      name: 'array body with single layer behaves like object body',
      input:: {
        path: ['demo'],
        body: [{ base: true }],
      },
      expected: {
        _node: true,
        base: true,
      },
    },
  ],
};

local graphTests = {
  name: 'graph',
  output(input):: graph(input),
  tests: [
    {
      name: 'intermediate objects carry their path template and variables as hidden fields',
      input:: {
        nodeSpecs: [[['kubernetes', '$context', 'metrics', 'pods'], { kind: 'chart' }]],
      },
      output(input)::
        local metrics = graph(input).kubernetes.context('prod').metrics;
        {
          metrics: metrics,
          pathTemplate: metrics._pathTemplate,
          context: metrics.context,
        },
      expected: {
        metrics: { pods: { _node: true, context: 'prod', kind: 'chart' } },
        pathTemplate: ['kubernetes', '$context', 'metrics'],
        context: 'prod',
      },
    },
    {
      name: 'turns variable path segments into functions',
      input:: {
        nodeSpecs: [
          [['kubernetes', '$context', '$namespace', 'pods'], { kind: 'Pod' }],
        ],
      },
      output(input):: graph(input).kubernetes.context('prod').namespace('default').pods,
      expected: {
        _node: true,
        context: 'prod',
        namespace: 'default',
        kind: 'Pod',
      },
    },
    {
      name: 'keeps static siblings beside variable segments',
      input:: {
        nodeSpecs: [
          [['kubernetes', '$context', 'pods'], { kind: 'Pod' }],
          [['kubernetes', 'api-resources'], { kind: 'APIResourceList' }],
        ],
      },
      output(input)::
        local root = graph(input).kubernetes;
        {
          static: root['api-resources'],
          dynamic: root.context('prod').pods,
        },
      expected: {
        static: {
          _node: true,
          kind: 'APIResourceList',
        },
        dynamic: {
          _node: true,
          context: 'prod',
          kind: 'Pod',
        },
      },
    },
    {
      name: 'default view applies to root, containers, and nodes',
      input:: {
        nodeSpecs: [
          [['group', '$name', 'detail'], { value: 1 }],
        ],
        defaultView: { _view: 'default' },
      },
      output(input)::
        local root = graph(input);
        {
          rootView: root._view,
          groupView: root.group._view,
          nameView: root.group.name('demo')._view,
          detail: root.group.name('demo').detail,
        },
      expected: {
        rootView: 'default',
        groupView: 'default',
        nameView: 'default',
        detail: {
          _node: true,
          _view: 'default',
          name: 'demo',
          value: 1,
        },
      },
    },
    {
      name: 'does not override node view',
      input:: {
        nodeSpecs: [
          [['demo'], { _view:: 'custom', value: 1 }],
        ],
        defaultView: { _view: 'default' },
      },
      output(input):: graph(input).demo._view,
      expected: 'custom',
    },
    {
      name: 'keeps static child below prefix node',
      input:: {
        nodeSpecs: [
          [['apps'], { title: 'Apps' }],
          [['apps', 'api'], { port: 8080 }],
        ],
      },
      output(input)::
        local apps = graph(input).apps;
        {
          node: {
            _node: apps._node,
            queryPath: apps._queryPath,
            title: apps.title,
          },
          child: apps.api,
        },
      expected: {
        node: {
          _node: true,
          queryPath: '/root/apps',
          title: 'Apps',
        },
        child: {
          _node: true,
          port: 8080,
        },
      },
    },
    {
      name: 'turns variable child below prefix node into function',
      input:: {
        nodeSpecs: [
          [['namespaces'], { title: 'Namespaces' }],
          [['namespaces', '$name', 'pods'], { kind: 'PodList' }],
        ],
      },
      output(input)::
        local namespaces = graph(input).namespaces;
        {
          node: {
            _node: namespaces._node,
            queryPath: namespaces._queryPath,
            title: namespaces.title,
          },
          child: namespaces.name('default').pods,
        },
      expected: {
        node: {
          _node: true,
          queryPath: '/root/namespaces',
          title: 'Namespaces',
        },
        child: {
          _node: true,
          name: 'default',
          kind: 'PodList',
        },
      },
    },
    {
      name: 'variadic spec merges layers in source order',
      input:: {
        nodeSpecs: [
          [['demo'], { value: 'base' }, { value: 'middle' }, { value: 'final', extra: true }],
        ],
      },
      output(input):: graph(input).demo,
      expected: {
        _node: true,
        value: 'final',
        extra: true,
      },
    },
    {
      name: 'multiple specs at the same path merge in source order',
      input:: {
        nodeSpecs: [
          [['demo'], { n: 1, label: 'first' }],
          [['demo'], { label: 'second', extra: true }],
        ],
      },
      output(input):: graph(input).demo,
      expected: {
        _node: true,
        n: 1,
        label: 'second',
        extra: true,
      },
    },
    {
      name: 'layer with _view suppresses default view under merge',
      input:: {
        nodeSpecs: [
          [['demo'], { n: 1 }],
          [['demo'], { _view:: 'custom' }],
        ],
        defaultView: { _view: 'default' },
      },
      output(input):: graph(input).demo._view,
      expected: 'custom',
    },
    {
      name: 'variable specs with different var names stay as siblings',
      input:: {
        nodeSpecs: [
          [['parents', '$a'], { from: 'a' }],
          [['parents', '$b'], { from: 'b' }],
        ],
      },
      output(input)::
        local parents = graph(input).parents;
        {
          a: parents.a('x'),
          b: parents.b('y'),
        },
      expected: {
        a: {
          _node: true,
          a: 'x',
          from: 'a',
        },
        b: {
          _node: true,
          b: 'y',
          from: 'b',
        },
      },
    },
    {
      name: 'specializing an existing node takes the new path and keeps inherited fields',
      input:: {
        nodeSpecs: [
          [['incidents'], {
            local n = self,
            _paramSpecs: [{ name: 'status', type: 'string', default: null }],
            data: { status: std.get(n._params, 'status', null) },
          }],
          [['incidents', 'triggered'], specialRoot.incidents { _params+: { status: 'triggered' } }],
        ],
      },
      local specialRoot = graph(self.input),
      output(input)::
        local triggered = graph(input).incidents.triggered;
        {
          evalPath: triggered._evalPath,
          queryPath: triggered._queryPath,
          pathTemplate: triggered._pathTemplate,
          data: triggered.data,
          baseData: graph(input).incidents.data,
        },
      expected: {
        evalPath: 'root.incidents.triggered',
        queryPath: '/root/incidents/triggered',
        pathTemplate: ['incidents', 'triggered'],
        data: { status: 'triggered' },
        baseData: { status: null },
      },
    },
    {
      name: 'spec with no layers still establishes the node',
      input:: {
        nodeSpecs: [
          [['demo']],
        ],
      },
      output(input):: graph(input).demo,
      expected: {
        _node: true,
      },
    },
  ],
};

local viaShape(input) =
  local nodeSpecs = input.nodeSpecs;
  local defaultView = std.get(input, 'defaultView', {});
  local layers = g.toLayers(nodeSpecs);
  local compiledShape = std.parseJson(std.manifestJsonEx(g.shape(layers), ''));
  g.graphFromShape(nodeSpecs, compiledShape, defaultView);

local shapeTests = {
  name: 'shape + graphFromShape',
  output(input):: viaShape(input),
  tests: [
    {
      name: 'turns variable path segments into functions',
      input:: {
        nodeSpecs: [
          [['kubernetes', '$context', '$namespace', 'pods'], { kind: 'Pod' }],
        ],
      },
      output(input):: viaShape(input).kubernetes.context('prod').namespace('default').pods,
      expected: {
        _node: true,
        context: 'prod',
        namespace: 'default',
        kind: 'Pod',
      },
    },
    {
      name: 'keeps static siblings beside variable segments',
      input:: {
        nodeSpecs: [
          [['kubernetes', '$context', 'pods'], { kind: 'Pod' }],
          [['kubernetes', 'api-resources'], { kind: 'APIResourceList' }],
        ],
      },
      output(input)::
        local root = viaShape(input).kubernetes;
        {
          static: root['api-resources'],
          dynamic: root.context('prod').pods,
        },
      expected: {
        static: {
          _node: true,
          kind: 'APIResourceList',
        },
        dynamic: {
          _node: true,
          context: 'prod',
          kind: 'Pod',
        },
      },
    },
    {
      name: 'default view applies to root, containers, and nodes',
      input:: {
        nodeSpecs: [
          [['group', '$name', 'detail'], { value: 1 }],
        ],
        defaultView: { _view: 'default' },
      },
      output(input)::
        local root = viaShape(input);
        {
          rootView: root._view,
          groupView: root.group._view,
          nameView: root.group.name('demo')._view,
          detail: root.group.name('demo').detail,
        },
      expected: {
        rootView: 'default',
        groupView: 'default',
        nameView: 'default',
        detail: {
          _node: true,
          _view: 'default',
          name: 'demo',
          value: 1,
        },
      },
    },
    {
      name: 'variadic spec merges layers in source order',
      input:: {
        nodeSpecs: [
          [['demo'], { value: 'base' }, { value: 'middle' }, { value: 'final', extra: true }],
        ],
      },
      output(input):: viaShape(input).demo,
      expected: {
        _node: true,
        value: 'final',
        extra: true,
      },
    },
    {
      name: 'multiple specs at the same path merge in source order',
      input:: {
        nodeSpecs: [
          [['demo'], { n: 1, label: 'first' }],
          [['demo'], { label: 'second', extra: true }],
        ],
      },
      output(input):: viaShape(input).demo,
      expected: {
        _node: true,
        n: 1,
        label: 'second',
        extra: true,
      },
    },
    {
      name: 'shape never forces layer bodies (functions survive round-trip)',
      input:: {
        nodeSpecs: [
          [['demo'], { render: function(x) x + 1 }],
        ],
      },
      output(input):: viaShape(input).demo.render(41),
      expected: 42,
    },
  ],
};

{
  tests: [
    nodeTests,
    graphTests,
    shapeTests,
  ],
}
