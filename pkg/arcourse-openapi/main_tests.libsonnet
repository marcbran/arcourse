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
              at: [],
              keys: [{ path: ['name'] }],
              value: [
                { const: 'repos' },
                { param: 'owner', path: ['owner', 'login'] },
                { param: 'repo', path: ['name'] },
              ],
            },
          ],
          columns: [
            { sourcePath: '/user/repos', array: [] },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local path = [part.expr.value for part in specNode.elements[0].expr.elements];
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local view = merged.left;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local table = [f for f in body.fields if f.id == 'table'][0].expr2;
        local columns = [f for f in table.fields if f.id == 'columns'][0].expr2;
        {
          path: path,
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          dataHide: body.fields[0].Hide,
          specsHide: specsField.Hide,
          specs: [manifestLiteral(e.expr) for e in specsField.expr2.elements],
          viewBase: view.target.target.id,
          viewName: view.target.id,
          columnCount: std.length(columns.elements),
          columnLabels: [
            [f.expr2.value for f in col.expr.fields if f.id == 'label'][0]
            for col in columns.elements
          ],
        },
      expected: {
        path: ['demo', 'user', 'repos'],
        nodeElementCount: 2,
        fieldNames: ['data', 'linkSpecs', 'table'],
        dataHide: 1,
        specsHide: 0,
        specs: [
          {
            at: [],
            keys: [{ path: ['name'] }],
            value: [
              { const: 'demo' },
              { const: 'repos' },
              { param: 'owner', path: ['owner', 'login'] },
              { param: 'repo', path: ['name'] },
            ],
          },
        ],
        viewBase: 'a',
        viewName: 'table',
        columnCount: 2,
        columnLabels: ['owner', 'repo'],
      },
    },
    {
      name: 'table.at follows the link anchor, not columns.json, when both are present',
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
              at: ['items'],
              keys: [{ path: ['name'] }],
              value: [
                { const: 'repos' },
                { param: 'repo', path: ['name'] },
              ],
            },
          ],
          columns: [
            { sourcePath: '/user/repos', array: ['stale_or_wrong'] },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local table = [f for f in body.fields if f.id == 'table'][0].expr2;
        local at = [f for f in table.fields if f.id == 'at'][0];
        {
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          tableAt: manifestLiteral(at.expr2),
          specAt: [manifestLiteral(e.expr).at for e in specsField.expr2.elements],
        },
      expected: {
        nodeElementCount: 2,
        fieldNames: ['data', 'linkSpecs', 'table'],
        tableAt: ['items'],
        specAt: [['items']],
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
              at: [],
              keys: [{ path: ['name'] }],
              value: [
                { const: 'repos' },
                { param: 'owner', path: ['owner', 'login'] },
                { param: 'repo', path: ['name'] },
              ],
            },
          ],
          columns: [
            {
              sourcePath: '/user/repos',
              array: [],
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
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local view = merged.left;
        local table = [f for f in body.fields if f.id == 'table'][0].expr2;
        local columns = [f for f in table.fields if f.id == 'columns'][0].expr2;
        {
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          viewName: view.target.id,
          columnCount: std.length(columns.elements),
          firstColumnFieldNames: [f.id for f in columns.elements[0].expr.fields],
          secondColumnFieldNames: [f.id for f in columns.elements[1].expr.fields],
        },
      expected: {
        nodeElementCount: 2,
        fieldNames: ['data', 'linkSpecs', 'table'],
        viewName: 'table',
        columnCount: 2,
        firstColumnFieldNames: ['label', 'path'],
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
              at: [],
              keys: [],
              value: [
                { const: 'current-status' },
              ],
            },
          ],
          columns: [
            { sourcePath: '/status', array: [] },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local view = merged.left;
        {
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          viewName: view.target.id,
        },
      expected: {
        nodeElementCount: 2,
        fieldNames: ['data', 'linkSpecs'],
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
        local bodyFieldCount(spec) = std.length(spec.expr.elements[1].expr.right.fields);
        {
          paths: [path(spec) for spec in specs],
          nodeElements: std.length(specs[0].expr.elements),
          bodyKind: specs[0].expr.elements[1].expr.__kind__,
          bodyFields: bodyFieldCount(specs[0]),
        },
      expected: {
        paths: [
          ['github', 'users', '$username'],
        ],
        nodeElements: 2,
        bodyKind: 'Binary',
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
        local requestApply(spec) = spec.expr.elements[1].expr.right.fields[0].expr2;
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
          ['github', '$region', '$tenant', 'users', '$username'],
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
        local requestApply(spec) = spec.expr.elements[1].expr.right.fields[0].expr2;
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
              orgs: {
                children: {
                  '{org}': {
                    children: {
                      repos: {
                        operation: {
                          pathFormat: '/orgs/%s/repos',
                          pathArgNames: ['org'],
                        },
                      },
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
              sourcePath: '/orgs/{org}/repos',
              at: [],
              keys: [{ path: ['name'] }],
              value: [
                { const: 'repos' },
                { param: 'repo', path: ['name'] },
              ],
            },
          ],
          columns: [
            { sourcePath: '/orgs/{org}/repos', array: [] },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr.right;
        {
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          dataHide: body.fields[0].Hide,
        },
      expected: {
        nodeElementCount: 2,
        fieldNames: ['data', 'linkSpecs', 'table'],
        dataHide: 1,
      },
    },
    {
      name: 'resource operation with a root-anchored resource link gets linkSpecs prefixed with root and service, no local resourcelinks import',
      input:: function()
        local spec = {
          paths: {
            children: {
              accounts: {
                children: {
                  '$id': {
                    operation: {
                      pathFormat: '/accounts/%s',
                      pathArgNames: ['id'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          links: [
            {
              sourcePath: '/accounts/{id}',
              at: [],
              keys: [{ const: 'service' }],
              value: [{ const: 'services' }, { param: 'id', path: ['service_id'] }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local binds(node, acc=[]) =
          if node.__kind__ == 'Local' then binds(node.body, acc + [b.variable for b in node.binds])
          else acc;
        local specNode = unwrap(generated).elements[0].expr;
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local specsElements = specsField.expr2.elements;
        local firstValueElements = specsElements[0].expr.fields[2].expr2.elements;
        {
          localVars: binds(generated),
          nodeElementCount: std.length(specNode.elements),
          bodyFieldNames: [f.id for f in body.fields],
          dataHide: [f for f in body.fields if f.id == 'data'][0].Hide,
          specsHide: specsField.Hide,
          specsCount: std.length(specsElements),
          specsFirstKind: specsElements[0].expr.__kind__,
          entryFieldNames: [f.id for f in specsElements[0].expr.fields],
          valueFirstSegmentConst: firstValueElements[0].expr.fields[0].expr2.value,
        },
      expected: {
        localVars: ['a'],
        nodeElementCount: 2,
        bodyFieldNames: ['data', 'linkSpecs'],
        dataHide: 1,
        specsHide: 0,
        specsCount: 1,
        specsFirstKind: 'Object',
        entryFieldNames: ['at', 'keys', 'value'],
        valueFirstSegmentConst: 'acme',
      },
    },
    {
      name: 'resource operation without matching resource links stays plain',
      input:: function()
        local spec = {
          paths: {
            children: {
              accounts: {
                children: {
                  '$id': {
                    operation: {
                      pathFormat: '/accounts/%s',
                      pathArgNames: ['id'],
                    },
                  },
                },
              },
              teams: {
                children: {
                  '$id': {
                    operation: {
                      pathFormat: '/teams/%s',
                      pathArgNames: ['id'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          links: [
            {
              sourcePath: '/accounts/{id}',
              at: [],
              keys: [{ const: 'service' }],
              value: [{ const: 'services' }, { param: 'id', path: ['service_id'] }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specs = unwrap(generated).elements;
        local pathOf(spec) = [part.expr.value for part in spec.expr.elements[0].expr.elements];
        local nodeFor(target) = [s for s in specs if pathOf(s) == target][0];
        {
          accountsElementCount: std.length(nodeFor(['acme', 'accounts', '$id']).expr.elements),
          teamsElementCount: std.length(nodeFor(['acme', 'teams', '$id']).expr.elements),
          accountsBodyFieldNames: [f.id for f in nodeFor(['acme', 'accounts', '$id']).expr.elements[1].expr.right.fields],
          teamsBodyFieldNames: [f.id for f in nodeFor(['acme', 'teams', '$id']).expr.elements[1].expr.right.fields],
        },
      expected: {
        accountsElementCount: 2,
        teamsElementCount: 2,
        accountsBodyFieldNames: ['data', 'linkSpecs'],
        teamsBodyFieldNames: ['data'],
      },
    },
    {
      name: 'resource link spec array-crossing entry embeds nested keys and a param-sourced path segment as literal data',
      input:: function()
        local spec = {
          paths: {
            children: {
              accounts: {
                children: {
                  '$id': {
                    operation: {
                      pathFormat: '/accounts/%s',
                      pathArgNames: ['id'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          links: [
            {
              sourcePath: '/accounts/{id}',
              at: ['members'],
              keys: [{ const: 'members' }, { path: ['user_id'] }],
              value: [{ const: 'users' }, { param: 'id', path: ['user_id'] }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local specsElements = specsField.expr2.elements;
        {
          specs: [manifestLiteral(e.expr) for e in specsElements],
        },
      expected: {
        specs: [
          {
            at: ['members'],
            keys: [{ const: 'members' }, { path: ['user_id'] }],
            value: [{ const: 'acme' }, { const: 'users' }, { param: 'id', path: ['user_id'] }],
          },
        ],
      },
    },
    {
      name: 'resource link with an origin-sourced param embeds identically as literal data, no special-case AST',
      input:: function()
        local spec = {
          paths: {
            children: {
              accounts: {
                children: {
                  '$id': {
                    children: {
                      integrations: {
                        children: {
                          '$integration_id': {
                            operation: {
                              pathFormat: '/accounts/%s/integrations/%s',
                              pathArgNames: ['id', 'integration_id'],
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          links: [
            {
              sourcePath: '/accounts/{id}/integrations/{integration_id}',
              at: [],
              keys: [{ const: 'account' }],
              value: [{ const: 'accounts' }, { origin: 'id' }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local specsElements = specsField.expr2.elements;
        {
          specs: [manifestLiteral(e.expr) for e in specsElements],
        },
      expected: {
        specs: [
          {
            at: [],
            keys: [{ const: 'account' }],
            value: [{ const: 'acme' }, { const: 'accounts' }, { origin: 'id' }],
          },
        ],
      },
    },
    {
      name: 'a collection with no links still renders as a table, falling back to columns.json for table.at',
      input:: function()
        local spec = {
          paths: {
            children: {
              events: {
                operation: {
                  pathFormat: '/events',
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'demo',
          manifest: false,
          columns: [
            {
              sourcePath: '/events',
              array: ['data'],
              columns: [{ label: 'Summary', path: ['summary'] }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local merged = specNode.elements[1].expr;
        local body = merged.right;
        local table = [f for f in body.fields if f.id == 'table'][0].expr2;
        {
          nodeElementCount: std.length(specNode.elements),
          fieldNames: [field.id for field in body.fields],
          viewName: merged.left.target.id,
          tableAt: manifestLiteral([f for f in table.fields if f.id == 'at'][0].expr2),
        },
      expected: {
        nodeElementCount: 2,
        fieldNames: ['data', 'table'],
        viewName: 'table',
        tableAt: ['data'],
      },
    },
    {
      name: 'a singleton resource with a link is not mistaken for a collection despite its path having no parameter',
      input:: function()
        local spec = {
          paths: {
            children: {
              user: {
                operation: {
                  pathFormat: '/user',
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
              sourcePath: '/user',
              at: [],
              keys: [{ const: 'company' }],
              value: [{ const: 'orgs' }, { param: 'org', path: ['company'] }],
            },
          ],
          collections: [],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr.right;
        {
          nodeElementCount: std.length(specNode.elements),
          bodyFieldNames: [f.id for f in body.fields],
          dataHide: [f for f in body.fields if f.id == 'data'][0].Hide,
        },
      expected: {
        nodeElementCount: 2,
        bodyFieldNames: ['data', 'linkSpecs'],
        dataHide: 1,
      },
    },
    {
      name: 'context params are woven into resource linkSpecs as origin segments, between service and the link value',
      input:: function()
        local spec = {
          paths: {
            children: {
              accounts: {
                children: {
                  '$id': {
                    operation: {
                      pathFormat: '/accounts/%s',
                      pathArgNames: ['id'],
                    },
                  },
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          contextParams: ['region'],
          links: [
            {
              sourcePath: '/accounts/{id}',
              at: [],
              keys: [{ const: 'service' }],
              value: [{ const: 'services' }, { param: 'id', path: ['service_id'] }],
            },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local specNode = unwrap(generated).elements[0].expr;
        local body = specNode.elements[1].expr.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        {
          specs: [manifestLiteral(e.expr) for e in specsField.expr2.elements],
        },
      expected: {
        specs: [
          {
            at: [],
            keys: [{ const: 'service' }],
            value: [
              { const: 'acme' },
              { origin: 'region' },
              { const: 'services' },
              { param: 'id', path: ['service_id'] },
            ],
          },
        ],
      },
    },
    {
      name: 'a context param needing mangling is woven in under its mangled node field name, so resolveTarget can find it',
      input:: function()
        local spec = {
          paths: {
            children: {
              widgets: {
                operation: {
                  pathFormat: '/widgets',
                },
              },
            },
          },
        };
        local generated = arcourseOpenapi.graph {
          service: 'acme',
          manifest: false,
          contextParams: ['self'],
          links: [
            {
              sourcePath: '/widgets',
              at: [],
              keys: [{ path: ['name'] }],
              value: [
                { const: 'widgets' },
                { param: 'id', path: ['name'] },
              ],
            },
          ],
          columns: [
            { sourcePath: '/widgets', array: [] },
          ],
          data+: {
            spec: spec,
          },
        }._view.jsonnet;
        local manifestLiteral(expr) =
          if expr.__kind__ == 'LiteralString' then expr.value
          else if expr.__kind__ == 'Array' then [manifestLiteral(e.expr) for e in expr.elements]
          else if expr.__kind__ == 'Object' then { [f.id]: manifestLiteral(f.expr2) for f in expr.fields }
          else error 'unexpected kind ' + expr.__kind__;
        local unwrap(node) = if node.__kind__ == 'Local' then unwrap(node.body) else node;
        local body = unwrap(generated).elements[0].expr.elements[1].expr.right;
        local specsField = [f for f in body.fields if f.id == 'linkSpecs'][0];
        local origin = [manifestLiteral(e.expr).value[1] for e in specsField.expr2.elements][0];
        {
          originKeyIsMangled: origin.origin != 'self',
          originKeyLooksHashed: std.startsWith(origin.origin, 'p_'),
        },
      expected: {
        originKeyIsMangled: true,
        originKeyLooksHashed: true,
      },
    },
  ],
}
