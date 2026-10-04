local a = import '../arcourse-ui/main.libsonnet';
local root = import 'root';
local invoke(name, args=[]) = std.native('invoke:course')(name, args);
local unrecorded = { _record: false };

local visitItem = {
  local c = self,
  node:: error 'VisitItem requires a node',
  html: [
    {
      element: 'a',
      attributes: { href: c.node.link },
      children: [c.node.address],
    },
    {
      element: 'span',
      attributes: { class: 'detail' },
      children: [c.node.time],
    },
  ],
};

[
  [['arcourse', 'sessions'], a.table.node + unrecorded {
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
  [['arcourse', '$session'], a.tree.node + unrecorded {
    data: invoke('session', [$.session]),
    local visitOf = { [visit.visitId]: visit for visit in $.data.visits },
    local parentOf = { [edge.to]: edge.from for edge in $.data.edges },
    local childIdsOf(visitId) = [edge.to for edge in $.data.edges if edge.from == visitId],
    local branchOf(visitId) = {
      local visit = visitOf[visitId],
      address: visit.address,
      time: std.substr(visit.timestamp, 11, 8),
      link: root.arcourse.session($.session).visit(visitId)._queryPath,
      children: [branchOf(childId) for childId in childIdsOf(visitId)],
    },
    tree:: {
      nodes: [
        branchOf(visit.visitId)
        for visit in $.data.visits
        if !std.objectHas(parentOf, visit.visitId)
      ],
      item: visitItem,
    },
  }],
  [['arcourse', '$session', '$visit'], a.resource.node + unrecorded {
    data: invoke('visit', [$.visit]),
    links: {
      [evaluation.evaluationId]: root.arcourse.session($.session).visit($.visit).evaluation(evaluation.evaluationId)
      for evaluation in $.data.evaluations
    } + {
      node: { _node: true, _queryPath: '/' + $.data.address },
      session: root.arcourse.session($.session),
    },
  }],
  [['arcourse', '$session', '$visit', '$evaluation'], a.resource.node + unrecorded {
    data: invoke('evaluation', [$.evaluation]),
    links: {
      node: { _node: true, _queryPath: '/' + $.data.address },
      visit: root.arcourse.session($.session).visit($.visit),
      session: root.arcourse.session($.session),
    },
  }],
  [['arcourse', '$session', '$visit', '$evaluation', 'html'], unrecorded {
    _view:: { html: invoke('content', [$.evaluation, 'html']) },
  }],
  [['arcourse', '$session', '$visit', '$evaluation', 'json'], a.yaml.node + unrecorded {
    local content = std.parseJson(invoke('content', [$.evaluation, 'json'])),
    data: {
      [key]: content[key]
      for key in std.objectFields(content)
      if key != '_node'
    },
  }],
]
