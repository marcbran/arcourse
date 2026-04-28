local arcourseKubectl = import './main.libsonnet';

{
  output(input):: input(),
  tests: [
    {
      name: 'exports graph package entrypoint',
      input:: function() std.objectFields(arcourseKubectl),
      expected: ['graph'],
    },
    {
      name: 'graph exposes data and view fields',
      input:: function()
        local graph = arcourseKubectl.graph;
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
      name: 'graph accepts provided resource data without calling kubectl',
      input:: function()
        local resources = [
          {
            name: 'pods',
            kind: 'Pod',
            namespaced: true,
            verbs: ['get', 'list'],
          },
        ];
        local graph = arcourseKubectl.graph {
          context: 'prod',
          data+: {
            resources: resources,
          },
        };
        {
          resources: graph.data.resources,
          viewFields: std.objectFieldsAll(graph._view),
        },
      expected: {
        resources: [
          {
            name: 'pods',
            kind: 'Pod',
            namespaced: true,
            verbs: ['get', 'list'],
          },
        ],
        viewFields: ['jsonnet'],
      },
    },
    {
      name: 'simple k8s resources output jsonnet object',
      input:: function()
        local resources = [
          {
            name: 'pods',
            kind: 'Pod',
            namespaced: true,
            verbs: ['get', 'list'],
          },
          {
            name: 'namespaces',
            kind: 'Namespace',
            namespaced: false,
            verbs: ['get', 'list'],
          },
        ];
        local generated = arcourseKubectl.graph {
          context: 'prod',
          manifest: false,
          data+: {
            resources: resources,
          },
        }._view.jsonnet;
        {
          type: std.type(generated),
          kind: generated.__kind__,
          bodyKind: generated.body.body.body.__kind__,
        },
      expected: {
        type: 'object',
        kind: 'Local',
        bodyKind: 'Array',
      },
    },
  ],
}
