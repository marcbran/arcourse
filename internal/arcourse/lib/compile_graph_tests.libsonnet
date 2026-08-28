local compile_graph = import './compile_graph.libsonnet';

{
  output(input):: compile_graph(input),
  tests: [
    {
      name: 'empty nodeSpecs yields empty shape',
      input:: [[]],
      expected: { leafs: [], children: {} },
    },
    {
      name: 'single nodeSpec produces leaf index at nested path',
      input:: [[[['demo'], { n: 1 }]]],
      expected: { leafs: [], children: { demo: { leafs: [0], children: {} } } },
    },
    {
      name: 'multiple nodeSpecs at distinct paths',
      input:: [[[['a'], { x: 1 }], [['b'], { y: 2 }]]],
      expected: {
        leafs: [],
        children: {
          a: { leafs: [0], children: {} },
          b: { leafs: [1], children: {} },
        },
      },
    },
    {
      name: 'variable path segment groups under var key',
      input:: [[[['namespaces', '$name', 'pods'], { kind: 'PodList' }]]],
      expected: {
        leafs: [],
        children: {
          namespaces: {
            leafs: [],
            children: {
              '$name': {
                leafs: [],
                children: { pods: { leafs: [0], children: {} } },
              },
            },
          },
        },
      },
    },
    {
      name: 'multiple layers at same path share one leaf index each',
      input:: [[[['demo'], { n: 1 }], [['demo'], { m: 2 }]]],
      expected: { leafs: [], children: { demo: { leafs: [0, 1], children: {} } } },
    },
    {
      name: 'shape output round-trips through JSON without loss',
      input:: [[[['demo'], { n: 1 }]]],
      output(input)::
        local s = compile_graph(input);
        std.parseJson(std.manifestJsonEx(s, '')) == s,
      expected: true,
    },
    {
      name: 'shape never forces the body (functions do not error)',
      input:: [[[['demo'], { render: function(x) x + 1 }]]],
      output(input)::
        local s = compile_graph(input);
        std.parseJson(std.manifestJsonEx(s, '')) == s,
      expected: true,
    },
  ],
}
