function(c)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local vars = params.vars;
    local labels = std.get(params, 'labels', vars);
    local titles = std.get(params, 'titles', [c.capitalize(v) for v in vars]);
    local metric = params.metric;
    local hidden = std.get(params, 'hidden', []);
    local n = std.length(vars);

    local pathSuffixes = [
      [vars[i] + 's', if i == n - 1 then metric else vars[n - 1] + c.capitalize(metric)]
      for i in std.range(0, n - 1)
    ] + [[metric]];

    local accs = c.accs(labels, vars);

    local placement(i) = if i == 0 then 'root' else vars[i - 1];

    local levelInputs = [
      local idx = if i == n then n - 1 else i;
      {
        placement: placement(i),
        isHidden: std.member(hidden, placement(i)),
        linksNext: i < n && !std.member(hidden, placement(i + 1)),
        isLeaf: i == n,
        label: labels[idx],
        var: vars[idx],
        title: titles[idx],
        ancestorVars: accs[i].ancestorVars,
        matchers: c.matcherClause(accs[i].matchers),
        path: base + ['$' + v for v in accs[i].ancestorVars] + ['metrics'] + pathSuffixes[i],
        nextPathSuffix: if i < n then ['metrics'] + pathSuffixes[i + 1] else null,
      }
      for i in std.range(0, n)
    ];

    [
      local ctx = params {
        groupBy:: li.label,
        matchers:: li.matchers,
        titleGroupBy:: if li.isLeaf then '' else 'by %s ' % li.title,
      };
      local override = std.get(std.get(ctx, 'levels', {}), li.placement, {});
      [li.path, ctx + override {
        queries: [
          {
            expr: $.expr % $,
            legendFormat: if std.objectHasAll($, 'legend') then $.legend else '{{%s}}' % ctx.groupBy,
            link:: if !li.linksNext then null else function(series)
              c.chainFields(
                c.chain(rootNode, [[v, $[v]] for v in li.ancestorVars] + [[li.var, series[li.label]]]),
                li.nextPathSuffix
              ),
          },
        ],
      }]
      for li in levelInputs
      if !li.isHidden
    ]
