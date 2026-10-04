local a = import '../arcourse-ui/main.libsonnet';
local root = import 'root';
local invoke(name, args=[]) = std.native('invoke:course')(name, args);

[
  [['arcourse', 'sessions'], a.table.node {
    data: { items: invoke('sessions') },
    table:: {
      at: ['items'],
      columns: [
        { label: 'Session', path: ['id'] },
        { label: 'Visits', path: ['visits'] },
        { label: 'First seen', path: ['first'] },
        { label: 'Last seen', path: ['last'] },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['id'] }],
        value: [{ const: 'arcourse' }, { param: 'session', path: ['id'] }],
      },
    ],
  }],
  [['arcourse', '$session'], a.resource.node {
    data: invoke('session', [$.session]),
    links: {
      [visit.visitId]: root.arcourse.session($.session).visit(visit.visitId)
      for visit in $.data.visits
    },
  }],
  [['arcourse', '$session', '$visit'], a.resource.node {
    data: invoke('visit', [$.visit]),
    links: {
      node: { _node: true, _queryPath: '/' + $.data.address },
      session: root.arcourse.session($.session),
    },
  }],
]
