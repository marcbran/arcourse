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
    {
      name: 'list operation includes matching links with hidden data',
      input:: function()
        local spec = {
          paths: {
            children: {
              user: {
                children: {
                  repos: {
                    operation: {
                      pathFormat: '/user/repos',
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'demo',
          manifest: false,
          links: [
            {
              sourcePath: '/user/repos',
              targetPath: '/repos/{owner}/{repo}',
              array: [],
              vars: {
                owner: ['owner', 'login'],
                repo: ['name'],
              },
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local path = [part.expr.value for part in specNode.elements[0].expr.elements];
        local body = specNode.elements[1].expr;
        local view = specNode.elements[2].expr;
        local links = body.fields[1].expr2;
        {
          path: path,
          fieldNames: [field.id for field in body.fields],
          dataHide: body.fields[0].Hide,
          linksKind: links.__kind__,
          linksTarget: links.target.id,
          argumentCount: std.length(links.arguments.positional),
          foldFunctionKind: links.arguments.positional[0].expr.__kind__,
          foldBodyKind: links.arguments.positional[0].expr.body.__kind__,
          viewBase: view.target.target.id,
          viewName: view.target.id,
        },
      expected: {
        path: ['demo', 'user', 'repos'],
        fieldNames: ['data', 'links'],
        dataHide: 0,
        linksKind: 'Apply',
        linksTarget: 'foldl',
        argumentCount: 3,
        foldFunctionKind: 'Function',
        foldBodyKind: 'Conditional',
        viewBase: 'a',
        viewName: 'list',
      },
    },
    {
      name: 'resource operation gets empty endpoint parent node',
      input:: function()
        local spec = {
          paths: {
            children: {
              users: {
                children: {
                  '{username}': {
                    operation: {
                      pathFormat: '/users/{username}',
                      pathArgNames: ['username'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'github',
          manifest: false,
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local specs = generated.body.elements;
        local path(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        local bodyFieldCount(spec) = std.length(spec.expr.elements[1].expr.fields);
        {
          paths: [path(spec) for spec in specs],
          parentIsEmpty: {
            specElements: std.length(specs[0].expr.elements),
            bodyFields: bodyFieldCount(specs[0]),
          },
        },
      expected: {
        paths: [
          ['github', 'users', '$username'],
          ['github', 'users', '$username', 'resource'],
        ],
        parentIsEmpty: {
          specElements: 2,
          bodyFields: 0,
        },
      },
    },
    {
      name: 'links match parameterized source path templates',
      input:: function()
        local spec = {
          paths: {
            children: {
              users: {
                children: {
                  '{username}': {
                    operation: {
                      pathFormat: '/users/%s',
                      pathArgNames: ['username'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'github',
          manifest: false,
          links: [
            {
              sourcePath: '/users/{username}',
              targetPath: '/users/{username}',
              array: [],
              vars: {
                username: ['login'],
              },
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local body = unwrap(generated).elements[0].expr.elements[1].expr;
        {
          fieldNames: [field.id for field in body.fields],
          dataHide: body.fields[0].Hide,
        },
      expected: {
        fieldNames: ['data', 'links'],
        dataHide: 0,
      },
    },
  ],
}
