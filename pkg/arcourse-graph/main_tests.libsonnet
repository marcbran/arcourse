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

{
  tests: [
    nodeTests,
    graphTests,
  ],
}
