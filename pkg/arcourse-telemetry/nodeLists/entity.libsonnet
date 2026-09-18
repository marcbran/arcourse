function(c, listNode, drilldown)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local vars = params.vars;
    local labels = std.get(params, 'labels', vars);
    local n = std.length(vars);
    local last = n - 1;

    local accs = c.accs(labels, vars);
    local ancestorVars = accs[last].ancestorVars;
    local matchers = c.matcherClause(accs[last].matchers);

    local collectionPath = base + ['$' + v for v in ancestorVars] + [vars[last] + 's'];
    local placeholderPath = base + ['$' + v for v in ancestorVars] + ['$' + vars[last]];

    local ctx = params { groupBy:: labels[last], matchers:: matchers };

    local browseEntries = [
      [collectionPath, listNode {
        expr:: ctx.listExpr % $,
        label:: labels[last],
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
