function(c, listNode, drilldown, logsNode)
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

    local entityEntries =
      if std.objectHasAll(params, 'entityPath') then
        local entityPath = params.entityPath;
        [
          [placeholderPath, { links+: { entity: c.walkPath(c.root, entityPath, [$[v] for v in vars]) } }],
          [entityPath, {
            local telemetry = c.chain(rootNode, [[v, $[v]] for v in vars]),
            links+: { telemetry: telemetry } + (if std.objectHas(telemetry, 'metrics') then { metrics: telemetry.metrics } else {}),
          }],
        ]
      else [[placeholderPath]];

    local browseEntries = [
      [collectionPath, listNode {
        expr:: ctx.listExpr % $,
        label:: labels[last],
        link:: function(name)
          c.chain(rootNode, [[v, $[v]] for v in ancestorVars] + [[vars[last], name]]),
      }],
    ] + entityEntries;

    local drillDowns = std.get(params, 'drillDowns', {});
    local drillDownEntries = std.flattenArrays([
      drilldown(params + drillDowns[metric] { metric:: metric })
      for metric in std.objectFields(drillDowns)
    ]);

    local logsEntries =
      if std.objectHasAll(params, 'logs') then
        [
          [placeholderPath + ['logs', view], logsNode + params.logs[view]]
          for view in std.objectFields(params.logs)
        ] + (
          if std.objectHasAll(params, 'entityPath') then
            [[params.entityPath, { links+: { logs: c.chain(rootNode, [[v, $[v]] for v in vars]).logs } }]]
          else []
        )
      else [];

    browseEntries + logsEntries + drillDownEntries
