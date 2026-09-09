function(c, chartNode)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local names = params.names;
    local vars = std.get(params, 'vars', names);
    local titles = std.get(params, 'titles', [c.capitalize(v) for v in vars]);
    local metric = params.metric;
    local unit = std.get(params, 'unit', null);
    local n = std.length(names);

    local pathSuffixes = [
      [vars[i] + 's', if i == n - 1 then metric else vars[n - 1] + c.capitalize(metric)]
      for i in std.range(0, n - 1)
    ] + [[metric]];

    local accs = c.accs(names, vars);

    local levelInputs = [
      local idx = if i == n then n - 1 else i;
      {
        isLeaf: i == n,
        name: names[idx],
        var: vars[idx],
        title: titles[idx],
        ancestorVars: accs[i].ancestorVars,
        matchers: c.matcherClause(accs[i].matchers),
        path: base + ['$' + v for v in accs[i].ancestorVars] + pathSuffixes[i],
        nextPathSuffix: if i < n then pathSuffixes[i + 1] else null,
      }
      for i in std.range(0, n)
    ];

    [
      local ctx = params {
        groupBy:: li.name,
        matchers:: li.matchers,
        titleGroupBy:: if li.isLeaf then '' else 'by %s ' % li.title,
      };
      [li.path, chartNode {
        title: ctx.title,
        unit:: unit,
        queries: [
          {
            expr: ctx.expr % $,
            legendFormat: if std.objectHasAll(params, 'legend') then ctx.legend else '{{%s}}' % ctx.groupBy,
            link:: if li.isLeaf then null else function(labels)
              c.chainFields(
                c.chain(rootNode, [[v, $[v]] for v in li.ancestorVars] + [[li.var, labels[li.name]]]),
                li.nextPathSuffix
              ),
          },
        ],
      }]
      for li in levelInputs
    ]
