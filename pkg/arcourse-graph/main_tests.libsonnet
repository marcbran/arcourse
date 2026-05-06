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
          urlPath: result._urlPath,
          vars: result._vars,
        },
      expected: {
        node: {
          _node: true,
          _path: 'root.kubernetes.context("prod").pods',
          context: 'prod',
          kind: 'Pod',
        },
        hasPathTemplate: true,
        hasVisiblePathTemplate: false,
        pathTemplate: ['kubernetes', '$context', 'pods'],
        urlPath: '/root/kubernetes/context/prod/pods',
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
        _path: 'root.demo',
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
        _path: 'root.demo',
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
        _path: 'root.demo',
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
        _path: 'root.kubernetes.context("prod").namespace("default").pods',
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
          _path: 'root.kubernetes.api-resources',
          kind: 'APIResourceList',
        },
        dynamic: {
          _node: true,
          _path: 'root.kubernetes.context("prod").pods',
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
          _path: 'root.group.name("demo").detail',
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
            _path: apps._path,
            title: apps.title,
          },
          child: apps.api,
        },
      expected: {
        node: {
          _node: true,
          _path: 'root.apps',
          title: 'Apps',
        },
        child: {
          _node: true,
          _path: 'root.apps.api',
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
            _path: namespaces._path,
            title: namespaces.title,
          },
          child: namespaces.name('default').pods,
        },
      expected: {
        node: {
          _node: true,
          _path: 'root.namespaces',
          title: 'Namespaces',
        },
        child: {
          _node: true,
          _path: 'root.namespaces.name("default").pods',
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
        _path: 'root.demo',
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
        _path: 'root.demo',
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
          _path: 'root.parents.a("x")',
          a: 'x',
          from: 'a',
        },
        b: {
          _node: true,
          _path: 'root.parents.b("y")',
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
        _path: 'root.demo',
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
