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
      name: 'graph accepts multiple contexts without single context',
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
          contexts: ['prod', 'dev'],
          manifest: false,
          data+: {
            resources: resources,
          },
        };
        {
          contexts: graph.data.contexts,
          viewKind: graph._view.jsonnet.__kind__,
        },
      expected: {
        contexts: ['prod', 'dev'],
        viewKind: 'Local',
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
    {
      name: 'resources with null verbs are treated as not having verbs',
      input:: function()
        local resources = [
          {
            name: 'pods',
            kind: 'Pod',
            namespaced: true,
            verbs: null,
          },
          {
            name: 'services',
            kind: 'Service',
            namespaced: true,
            verbs: ['list'],
          },
        ];
        local generated = arcourseKubectl.graph {
          context: 'prod',
          manifest: false,
          data+: {
            resources: resources,
          },
        }._view.jsonnet;
        local specs = generated.body.body.body.elements;
        local path(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        {
          paths: [path(spec) for spec in specs],
        },
      expected: {
        paths: [
          ['kubernetes', 'contexts'],
          ['kubernetes', '$context'],
          ['kubernetes', '$context', '$namespace'],
          ['kubernetes', '$context', 'api-resources'],
          ['kubernetes', '$context', 'services'],
          ['kubernetes', '$context', '$namespace', 'services'],
        ],
      },
    },
    {
      name: 'resource leaf nodes get empty parent nodes',
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
        local specs = generated.body.body.body.elements;
        local path(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        local bodyFieldCount(spec) = std.length(spec.expr.elements[1].expr.fields);
        {
          paths: [path(spec) for spec in specs],
          contextParentIsEmpty: {
            specElements: std.length(specs[1].expr.elements),
            bodyFields: bodyFieldCount(specs[1]),
          },
          namespaceParentIsEmpty: {
            specElements: std.length(specs[2].expr.elements),
            bodyFields: bodyFieldCount(specs[2]),
          },
          namespacedParentIsEmpty: {
            specElements: std.length(specs[6].expr.elements),
            bodyFields: bodyFieldCount(specs[6]),
          },
        },
      expected: {
        paths: [
          ['kubernetes', 'contexts'],
          ['kubernetes', '$context'],
          ['kubernetes', '$context', '$namespace'],
          ['kubernetes', '$context', 'api-resources'],
          ['kubernetes', '$context', 'pods'],
          ['kubernetes', '$context', '$namespace', 'pods'],
          ['kubernetes', '$context', '$namespace', '$pod'],
          ['kubernetes', '$context', '$namespace', '$pod', 'resource'],
          ['kubernetes', '$context', 'namespaces'],
          ['kubernetes', '$context', '$namespace', 'resource'],
        ],
        contextParentIsEmpty: {
          specElements: 2,
          bodyFields: 0,
        },
        namespaceParentIsEmpty: {
          specElements: 2,
          bodyFields: 0,
        },
        namespacedParentIsEmpty: {
          specElements: 2,
          bodyFields: 0,
        },
      },
    },
    {
      name: 'list nodes keep kubectl data hidden and expose links',
      input:: function()
        local resources = [
          {
            name: 'pods',
            kind: 'Pod',
            namespaced: true,
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
        local specs = generated.body.body.body.elements;
        local body = specs[4].expr.elements[1].expr;
        local links = body.fields[1].expr2;
        {
          fieldNames: [field.id for field in body.fields],
          dataHide: body.fields[0].Hide,
          linksKind: links.__kind__,
          linksTarget: links.target.id,
          linksSourceKind: links.arguments.positional[1].expr.__kind__,
        },
      expected: {
        fieldNames: ['data', 'links'],
        dataHide: 0,
        linksKind: 'Apply',
        linksTarget: 'foldl',
        linksSourceKind: 'Index',
      },
    },
    {
      name: 'resource route avoids item variable collision',
      input:: function()
        local resources = [
          {
            name: 'endpoints',
            kind: 'Endpoints',
            namespaced: true,
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
        local specs = generated.body.body.body.elements;
        local path(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        {
          paths: [path(spec) for spec in specs],
        },
      expected: {
        paths: [
          ['kubernetes', 'contexts'],
          ['kubernetes', '$context'],
          ['kubernetes', '$context', '$namespace'],
          ['kubernetes', '$context', 'api-resources'],
          ['kubernetes', '$context', 'endpointsList'],
          ['kubernetes', '$context', '$namespace', 'endpointsList'],
          ['kubernetes', '$context', '$namespace', '$endpoints'],
          ['kubernetes', '$context', '$namespace', '$endpoints', 'resource'],
        ],
      },
    },
  ],
}
