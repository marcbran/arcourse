local arcourseOpenapi = import './main.libsonnet';

{
  output(input):: input(),
  tests: [
    {
      name: 'exports graph package entrypoint',
      input:: function() std.objectFields(arcourseOpenapi),
      expected: ['graph'],
    },
    {
      name: 'graph exposes data and view fields',
      input:: function()
        local graph = arcourseOpenapi.graph;
        {
          hasView: std.objectHasAll(graph, '_view'),
          viewVisible: std.objectHas(graph, '_view'),
          viewFields: std.objectFieldsAll(graph._view),
        },
      expected: {
        hasView: true,
        viewVisible: false,
        viewFields: ['jsonnet'],
      },
    },
    {
      name: 'graph accepts provided nested spec data without calling openapi',
      input:: function()
        local spec = {
          paths: {
            children: {
              health: {
                operation: {
                  pathFormat: '/health',
                },
              },
            },
          },
        };
        local graph = arcourseOpenapi.graph {
          service: 'demo',
          data+: {
            spec: spec,
          },
        };
        {
          spec: graph.data.spec,
          viewFields: std.objectFieldsAll(graph._view),
        },
      expected: {
        spec: {
          paths: {
            children: {
              health: {
                operation: {
                  pathFormat: '/health',
                },
              },
            },
          },
        },
        viewFields: ['jsonnet'],
      },
    },
    {
      name: 'simple spec outputs jsonnet object',
      input:: function()
        local spec = {
          paths: {
            children: {
              health: {
                operation: {
                  pathFormat: '/health',
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'demo',
          manifest: false,
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        {
          type: std.type(generated),
          kind: generated.__kind__,
          bodyKind: generated.body.__kind__,
        },
      expected: {
        type: 'object',
        kind: 'Local',
        bodyKind: 'Array',
      },
    },
  ],
}
