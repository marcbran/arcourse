local g = import './main.libsonnet';

local node(input) = g.node(input.path, input.res, std.get(input, 'mixins', []));
local graph(input) = g.graph(input.nodeSpecs, std.get(input, 'defaultView', {}));
local merge(input) = g.merge(input.fragments, std.get(input, 'defaultView', {}));

local nodeTests = {
  name: 'node',
  output(input):: node(input),
  tests: [
    {
      name: 'exposes resolved path fields',
      input:: {
        path: ['kubernetes', '$context', 'pods'],
        res: { context: 'prod', kind: 'Pod' },
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
      name: 'applies object mixin',
      input:: {
        path: ['demo'],
        res: { base: true },
        mixins: { mixed: true },
      },
      expected: {
        _node: true,
        _path: 'root.demo',
        base: true,
        mixed: true,
      },
    },
    {
      name: 'applies mixins in order',
      input:: {
        path: ['demo'],
        res: { value: 'base' },
        mixins: [{ value: 'first' }, { value: 'second', extra: true }],
      },
      expected: {
        _node: true,
        _path: 'root.demo',
        value: 'second',
        extra: true,
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
  ],
};

local mergeTests = {
  name: 'merge',
  output(input):: merge(input),
  tests: [
    {
      name: 'deep merges plain containers',
      input:: {
        fragments: [
          { apps: { api: g.node(['apps', 'api'], { port: 8080 }) } },
          { apps: { web: g.node(['apps', 'web'], { port: 80 }) } },
        ],
      },
      output(input):: merge(input).apps,
      expected: {
        api: {
          _node: true,
          _path: 'root.apps.api',
          port: 8080,
        },
        web: {
          _node: true,
          _path: 'root.apps.web',
          port: 80,
        },
      },
    },
  ],
};

{
  tests: [
    nodeTests,
    graphTests,
    mergeTests,
  ],
}
