local generateGraphRoot = import './generate_graph_root.libsonnet';

{
  output(input):: generateGraphRoot(input.graphSpecExpr, input.shape),
  tests: [
    {
      name: 'empty shape yields the root node',
      input:: {
        graphSpecExpr: 'spec',
        shape: { leafs: [], children: {} },
      },
      expected: |||
        local g = import 'lib/arcourse-graph/main.libsonnet';
        local graphSpec = spec;
        local layers = g.toLayers(graphSpec[0]);
        local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
        local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
        local levels = {
          n0(vars):: view(g.intermediate([], vars) + {}),
        };
        view(g.node([]) + levels.n0({}))
      |||,
    },
    {
      name: 'variable children become functions and fixed children are called with the current vars',
      input:: {
        graphSpecExpr: 'spec',
        shape: { leafs: [], children: {
          ns: { leafs: [0], children: {
            '$name': { leafs: [1], children: {} },
            list: { leafs: [2], children: {} },
          } },
        } },
      },
      expected: |||
        local g = import 'lib/arcourse-graph/main.libsonnet';
        local graphSpec = spec;
        local layers = g.toLayers(graphSpec[0]);
        local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
        local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
        local levels = {
          n0(vars):: view(g.intermediate([], vars) + {
            "ns": levels.n1(vars),
          }),
          n1(vars):: view(g.node(layers[0].fullPath, [layers[0].layer], vars) + {
            "name": function(val) levels.n2(vars { "name": val }),
            "list": levels.n3(vars),
          }),
          s2:: g.shadowedVars(["ns","$name"], [layers[1].layer]),
          n2(vars):: view(g.node(layers[1].fullPath, [layers[1].layer], vars, levels.s2)),
          n3(vars):: view(g.node(layers[2].fullPath, [layers[2].layer], vars)),
        };
        view(g.node([]) + levels.n0({}))
      |||,
    },
    {
      name: 'all leafs at a path become layers and field names are quoted',
      input:: {
        graphSpecExpr: 'import "a.jsonnet"',
        shape: { leafs: [], children: {
          'my-app': { leafs: [0, 1], children: {
            '$the-var': { leafs: [2], children: {} },
          } },
        } },
      },
      expected: |||
        local g = import 'lib/arcourse-graph/main.libsonnet';
        local graphSpec = import "a.jsonnet";
        local layers = g.toLayers(graphSpec[0]);
        local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
        local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
        local levels = {
          n0(vars):: view(g.intermediate([], vars) + {
            "my-app": levels.n1(vars),
          }),
          n1(vars):: view(g.node(layers[0].fullPath, [layers[0].layer, layers[1].layer], vars) + {
            "the-var": function(val) levels.n2(vars { "the-var": val }),
          }),
          s2:: g.shadowedVars(["my-app","$the-var"], [layers[2].layer]),
          n2(vars):: view(g.node(layers[2].fullPath, [layers[2].layer], vars, levels.s2)),
        };
        view(g.node([]) + levels.n0({}))
      |||,
    },
    {
      name: 'variables with the name of a child are excluded from the top-level fields',
      input:: {
        graphSpecExpr: 'spec',
        shape: { leafs: [], children: {
          '$context': { leafs: [], children: {
            '$region': { leafs: [0], children: {
              context: { leafs: [1], children: {} },
            } },
            context: { leafs: [2], children: {} },
          } },
        } },
      },
      expected: |||
        local g = import 'lib/arcourse-graph/main.libsonnet';
        local graphSpec = spec;
        local layers = g.toLayers(graphSpec[0]);
        local defaultView = if std.length(graphSpec) > 1 then graphSpec[1] else {};
        local view(obj) = if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
        local levels = {
          n0(vars):: view(g.intermediate([], vars) + {
            "context": function(val) levels.n1(vars { "context": val }),
          }),
          n1(vars):: view(g.intermediate(["$context"], vars, ["context"]) + {
            "region": function(val) levels.n2(vars { "region": val }),
            "context": levels.n4(vars),
          }),
          s2:: g.shadowedVars(["$context","$region"], [layers[0].layer], ["context"]),
          n2(vars):: view(g.node(layers[0].fullPath, [layers[0].layer], vars, levels.s2) + {
            "context": levels.n3(vars),
          }),
          s3:: g.shadowedVars(["$context","$region","context"], [layers[1].layer]),
          n3(vars):: view(g.node(layers[1].fullPath, [layers[1].layer], vars, levels.s3)),
          s4:: g.shadowedVars(["$context","context"], [layers[2].layer]),
          n4(vars):: view(g.node(layers[2].fullPath, [layers[2].layer], vars, levels.s4)),
        };
        view(g.node([]) + levels.n0({}))
      |||,
    },
  ],
}
