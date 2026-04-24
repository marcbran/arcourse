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
      name: 'single nodeSpec three elements',
      input:: [[[['demo'], { n: 1 }, []]]],
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
      name: 'two element nodeSpec defaults mixins',
      input:: [[[['demo'], { n: 2 }]]],
      expected: {
        _node: true,
        _path: 'root',
        demo: {
          _node: true,
          _path: 'root.demo',
          n: 2,
        },
      },
    },
    {
      name: 'multiple nodeSpecs at distinct paths',
      input:: [[[['a'], { x: 1 }, []], [['b'], { y: 2 }, []]]],
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
      input:: [[[['a', 'b'], { k: 1 }, []]]],
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
      input:: [[[['x', 'y'], { u: 1 }, []], [['x', 'z'], { v: 2 }, []]]],
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
      name: 'prefix node and deeper static node can coexist',
      input:: [[[['a'], { label: 'prefix' }, []], [['a', 'b'], { label: 'deep' }, []]]],
      expected: {
        _node: true,
        _path: 'root',
        a: {
          _node: true,
          _path: 'root.a',
          label: 'prefix',
          b: {
            _node: true,
            _path: 'root.a.b',
            label: 'deep',
          },
        },
      },
    },
    {
      name: 'prefix node and deeper variable node can coexist',
      input:: [[[['courses', '$course'], { title: 'course' }, []], [['courses', '$course', 'lessons', '$lesson'], { title: 'lesson' }, []]]],
      output(input)::
        local out = construct_graph_root(input);
        {
          coursePath: out.courses.course('math')._path,
          lessonPath: out.courses.course('math').lessons.lesson('intro')._path,
        },
      expected: {
        coursePath: 'root.courses.course("math")',
        lessonPath: 'root.courses.course("math").lessons.lesson("intro")',
      },
    },
    {
      name: 'prefix-bound vars remain available deeper',
      input:: [[[['courses', '$course'], { title: 'course' }, []], [['courses', '$course', 'lessons', '$lesson'], { title: 'lesson' }, []]]],
      output(input)::
        local out = construct_graph_root(input);
        out.courses.course('math').lessons.lesson('intro')._path,
      expected: 'root.courses.course("math").lessons.lesson("intro")',
    },
  ],
}
