local construct_graph_root = import './construct_graph_root.libsonnet';

{
  output(input):: construct_graph_root(input),
  tests: [
    {
      name: 'empty nodeSpecs yields root shell',
      input:: [[]],
      expected: {
        _node: true,
        _path: 'root',
      },
    },
    {
      name: 'single nodeSpec with body layer',
      input:: [[[['demo'], { n: 1 }]]],
      expected: {
        _node: true,
        _path: 'root',
        demo: {
          _node: true,
          _path: 'root.demo',
          n: 1,
        },
      },
    },
    {
      name: 'single nodeSpec with no layers establishes node',
      input:: [[[['demo']]]],
      expected: {
        _node: true,
        _path: 'root',
        demo: {
          _node: true,
          _path: 'root.demo',
        },
      },
    },
    {
      name: 'multiple nodeSpecs at distinct paths',
      input:: [[[['a'], { x: 1 }], [['b'], { y: 2 }]]],
      expected: {
        _node: true,
        _path: 'root',
        a: {
          _node: true,
          _path: 'root.a',
          x: 1,
        },
        b: {
          _node: true,
          _path: 'root.b',
          y: 2,
        },
      },
    },
    {
      name: 'single nodeSpec with nested path',
      input:: [[[['a', 'b'], { k: 1 }]]],
      expected: {
        _node: true,
        _path: 'root',
        a: {
          b: {
            _node: true,
            _path: 'root.a.b',
            k: 1,
          },
        },
      },
    },
    {
      name: 'defaultView applied to nodes without _view',
      input:: [[[['demo'], { n: 1 }]], { _view: 'default' }],
      expected: {
        _node: true,
        _path: 'root',
        _view: 'default',
        demo: {
          _node: true,
          _path: 'root.demo',
          n: 1,
          _view: 'default',
        },
      },
    },
    {
      name: 'defaultView not applied to node with _view',
      input:: [[[['demo'], { n: 1, _view:: true }]], { _view: 'default' }],
      expected: {
        _node: true,
        _path: 'root',
        _view: 'default',
        demo: {
          _node: true,
          _path: 'root.demo',
          n: 1,
        },
      },
    },
    {
      name: 'two nodeSpecs with nested paths sharing prefix',
      input:: [[[['x', 'y'], { u: 1 }], [['x', 'z'], { v: 2 }]]],
      expected: {
        _node: true,
        _path: 'root',
        x: {
          y: {
            _node: true,
            _path: 'root.x.y',
            u: 1,
          },
          z: {
            _node: true,
            _path: 'root.x.z',
            v: 2,
          },
        },
      },
    },
    {
      name: 'nodeSpec can have static descendant nodeSpec',
      input:: [[[['x'], { u: 1 }], [['x', 'y'], { v: 2 }]]],
      expected: {
        _node: true,
        _path: 'root',
        x: {
          _node: true,
          _path: 'root.x',
          u: 1,
          y: {
            _node: true,
            _path: 'root.x.y',
            v: 2,
          },
        },
      },
    },
    {
      name: 'nodeSpec can have variable descendant nodeSpec',
      input:: [[[['namespaces'], { title: 'Namespaces' }], [['namespaces', '$name', 'pods'], { kind: 'PodList' }]]],
      output(input):: construct_graph_root(input).namespaces.name('default').pods,
      expected: {
        _node: true,
        _path: 'root.namespaces.name("default").pods',
        name: 'default',
        kind: 'PodList',
      },
    },
    {
      name: 'variadic spec merges layers in source order',
      input:: [[[['demo'], { value: 'base' }, { value: 'middle' }, { value: 'final', extra: true }]]],
      expected: {
        _node: true,
        _path: 'root',
        demo: {
          _node: true,
          _path: 'root.demo',
          value: 'final',
          extra: true,
        },
      },
    },
    {
      name: 'multiple nodeSpecs at same path merge in source order',
      input:: [[[['demo'], { n: 1, label: 'first' }], [['demo'], { label: 'second', extra: true }]]],
      expected: {
        _node: true,
        _path: 'root',
        demo: {
          _node: true,
          _path: 'root.demo',
          n: 1,
          label: 'second',
          extra: true,
        },
      },
    },
    {
      name: 'layer with _view from later spec suppresses defaultView',
      input:: [[[['demo'], { n: 1 }], [['demo'], { _view:: 'custom' }]], { _view: 'default' }],
      output(input):: construct_graph_root(input).demo._view,
      expected: 'custom',
    },
    {
      name: 'specs with different var names at same position stay as siblings',
      input:: [[[['parents', '$a'], { from: 'a' }], [['parents', '$b'], { from: 'b' }]]],
      output(input)::
        local parents = construct_graph_root(input).parents;
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
  ],
}
