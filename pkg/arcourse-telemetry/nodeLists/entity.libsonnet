function(c, listNode, drilldown)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local names = params.names;
    local vars = std.get(params, 'vars', names);
    local n = std.length(names);
    local last = n - 1;

    local accs = c.accs(names, vars);
    local ancestorVars = accs[last].ancestorVars;
    local matchers = c.matcherClause(accs[last].matchers);

    local collectionPath = base + ['$' + v for v in ancestorVars] + [vars[last] + 's'];
    local placeholderPath = base + ['$' + v for v in ancestorVars] + ['$' + vars[last]];

    local ctx = params { groupBy:: names[last], matchers:: matchers };

    local browseEntries = [
      [collectionPath, listNode {
        expr:: ctx.listExpr % $,
        label:: names[last],
        link:: function(name)
          c.chain(rootNode, [[v, $[v]] for v in ancestorVars] + [[vars[last], name]]),
      }],
      [placeholderPath],
    ];

    local drillDowns = std.get(params, 'drillDowns', {});
    local drillDownEntries = std.flattenArrays([
      drilldown(params + drillDowns[metric] { metric:: metric })
      for metric in std.objectFields(drillDowns)
    ]);

    browseEntries + drillDownEntries
