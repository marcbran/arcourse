local construct_graph_root = import './construct_graph_root.libsonnet';

{
  output(input):: construct_graph_root(input.nodeSpecs),
  tests: [
    {
      name: 'empty nodeSpecs yields root shell',
      input:: { nodeSpecs: [] },
      expected: {
        _node: true,
        _path: '.root',
      },
    },
    {
      name: 'single nodeSpec three elements',
      input:: { nodeSpecs: [[['demo'], { n: 1 }, []]] },
      expected: {
        _node: true,
        _path: '.root',
        demo: {
          _node: true,
          _path: '.root.demo',
          n: 1,
        },
      },
    },
    {
      name: 'two element nodeSpec defaults mixins',
      input:: { nodeSpecs: [[['demo'], { n: 2 }]] },
      expected: {
        _node: true,
        _path: '.root',
        demo: {
          _node: true,
          _path: '.root.demo',
          n: 2,
        },
      },
    },
    {
      name: 'multiple nodeSpecs at distinct paths',
      input:: { nodeSpecs: [[['a'], { x: 1 }, []], [['b'], { y: 2 }, []]] },
      expected: {
        _node: true,
        _path: '.root',
        a: {
          _node: true,
          _path: '.root.a',
          x: 1,
        },
        b: {
          _node: true,
          _path: '.root.b',
          y: 2,
        },
      },
    },
    {
      name: 'single nodeSpec with nested path',
      input:: { nodeSpecs: [[['a', 'b'], { k: 1 }, []]] },
      expected: {
        _node: true,
        _path: '.root',
        a: {
          b: {
            _node: true,
            _path: '.root.a.b',
            k: 1,
          },
        },
      },
    },
    {
      name: 'two nodeSpecs with nested paths sharing prefix',
      input:: { nodeSpecs: [[['x', 'y'], { u: 1 }, []], [['x', 'z'], { v: 2 }, []]] },
      expected: {
        _node: true,
        _path: '.root',
        x: {
          y: {
            _node: true,
            _path: '.root.x.y',
            u: 1,
          },
          z: {
            _node: true,
            _path: '.root.x.z',
            v: 2,
          },
        },
      },
    },
  ],
}
