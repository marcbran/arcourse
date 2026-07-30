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
      name: 'list operation includes matching links with hidden data and default columns per target param',
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
        local columns = body.fields[2].expr2;
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
          columnCount: std.length(columns.elements),
          columnLabels: [
            [f.expr2.value for f in col.expr.fields if f.id == 'label'][0]
            for col in columns.elements
          ],
          columnHasLink: [
            std.length([f for f in col.expr.fields if f.id == 'link']) > 0
            for col in columns.elements
          ],
        },
      expected: {
        path: ['demo', 'user', 'repos'],
        fieldNames: ['data', 'links', 'columns', 'itemsPath'],
        dataHide: 0,
        linksKind: 'Apply',
        linksTarget: 'foldl',
        argumentCount: 3,
        foldFunctionKind: 'Function',
        foldBodyKind: 'Conditional',
        viewBase: 'a',
        viewName: 'table',
        columnCount: 2,
        columnLabels: ['owner', 'repo'],
        columnHasLink: [false, true],
      },
    },
    {
      name: 'links fold source is guarded against non-array data',
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
        local body = specNode.elements[1].expr;
        local links = body.fields[1].expr2;
        local dataArg = links.arguments.positional[1].expr;
        {
          dataArgKind: dataArg.__kind__,
          guardKind: dataArg.body.__kind__,
          condKind: dataArg.body.cond.__kind__,
          fallbackKind: dataArg.body.branchFalse.__kind__,
        },
      expected: {
        dataArgKind: 'Local',
        guardKind: 'Conditional',
        condKind: 'Binary',
        fallbackKind: 'Array',
      },
    },
    {
      name: 'link target arguments are stringified even for non-string values',
      input:: function()
        local spec = {
          paths: {
            children: {
              pulls: {
                operation: {
                  pathFormat: '/pulls',
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
              sourcePath: '/pulls',
              targetPath: '/pulls/{pull_number}',
              array: [],
              vars: {
                pull_number: ['number'],
              },
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr;
        local columns = body.fields[2].expr2;
        local linkFn = [f for f in columns.elements[0].expr.fields if f.id == 'link'][0];
        local callArg = linkFn.expr2.arguments.positional[0].expr;
        {
          callArgKind: callArg.__kind__,
          callArgTarget: callArg.target.id,
          callArgBase: callArg.target.target.id,
        },
      expected: {
        callArgKind: 'Apply',
        callArgTarget: 'toString',
        callArgBase: 'std',
      },
    },
    {
      name: 'explicit columns config overrides the default column',
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
          columns: [
            {
              sourcePath: '/user/repos',
              columns: [
                { label: 'Name', path: ['name'], link: true },
                { label: 'Stars', path: ['stargazers_count'] },
              ],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr;
        local view = specNode.elements[2].expr;
        local columns = body.fields[2].expr2;
        {
          fieldNames: [field.id for field in body.fields],
          viewName: view.target.id,
          columnCount: std.length(columns.elements),
          firstColumnFieldNames: [f.id for f in columns.elements[0].expr.fields],
          secondColumnFieldNames: [f.id for f in columns.elements[1].expr.fields],
        },
      expected: {
        fieldNames: ['data', 'links', 'columns', 'itemsPath'],
        viewName: 'table',
        columnCount: 2,
        firstColumnFieldNames: ['label', 'path', 'link'],
        secondColumnFieldNames: ['label', 'path'],
      },
    },
    {
      name: 'link with no target params stays a plain list with no columns',
      input:: function()
        local spec = {
          paths: {
            children: {
              status: {
                operation: {
                  pathFormat: '/status',
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
              sourcePath: '/status',
              targetPath: '/current-status',
              array: [],
              vars: {},
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr;
        local view = specNode.elements[2].expr;
        {
          fieldNames: [field.id for field in body.fields],
          viewName: view.target.id,
        },
      expected: {
        fieldNames: ['data', 'links'],
        viewName: 'list',
      },
    },
    {
      name: 'resource operation attaches directly to its own path',
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
          nodeElements: std.length(specs[0].expr.elements),
          bodyFields: bodyFieldCount(specs[0]),
        },
      expected: {
        paths: [
          ['github', 'users', '$username'],
        ],
        nodeElements: 3,
        bodyFields: 1,
      },
    },
    {
      name: 'context params are prefixed onto every path and threaded into the request context',
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
          contextParams: ['region', 'tenant'],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local specs = generated.body.elements;
        local path(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        local requestApply(spec) = spec.expr.elements[1].expr.fields[0].expr2;
        local inputObjectExpr(spec) =
          requestApply(spec).arguments.positional[1].expr.elements[0].expr;
        local fieldNames(spec) = [f.id for f in inputObjectExpr(spec).fields];
        local contextField(spec) =
          local fields = inputObjectExpr(spec).fields;
          fields[std.length(fields) - 1];
        {
          paths: [path(spec) for spec in specs],
          inputFields: fieldNames(specs[0]),
          contextFieldId: contextField(specs[0]).id,
          contextValueFields: [f.id for f in contextField(specs[0]).expr2.fields],
        },
      expected: {
        paths: [
          ['github', 'region', '$region', 'tenant', '$tenant', 'users', '$username'],
        ],
        inputFields: ['method', 'path', 'context'],
        contextFieldId: 'context',
        contextValueFields: ['region', 'tenant'],
      },
    },
    {
      name: 'no context field is added when contextParams is empty',
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
        local requestApply(spec) = spec.expr.elements[1].expr.fields[0].expr2;
        local inputObjectExpr(spec) =
          requestApply(spec).arguments.positional[1].expr.elements[0].expr;
        local fieldNames(spec) = [f.id for f in inputObjectExpr(spec).fields];
        {
          inputFields: fieldNames(specs[0]),
        },
      expected: {
        inputFields: ['method', 'path'],
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
        fieldNames: ['data', 'links', 'columns', 'itemsPath'],
        dataHide: 0,
      },
    },
  ],
}
