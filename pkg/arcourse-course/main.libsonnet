local a = import '../arcourse-ui/main.libsonnet';
local root = import 'root';
local invoke(name, args=[]) = std.native('invoke:course')(name, args);
local unrecorded = { _record: false };

local evaluationContentStyle = |||
  .evaluation-content {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.25em;
    width: 75vw;
  }
  .evaluation-preview {
    box-sizing: border-box;
    width: 100%;
    height: 70vh;
    border: 1px solid var(--border-color);
    background: var(--background-color);
  }
|||;

local evaluationContent = {
  local c = self,
  content:: error 'EvaluationContent requires content',
  src:: error 'EvaluationContent requires a src',
  html: [
    { element: 'style', children: [evaluationContentStyle] },
    {
      element: 'div',
      attributes: { class: 'evaluation-content' },
      children: [
        c.content,
        {
          element: 'iframe',
          attributes: {
            class: 'evaluation-preview card',
            src: c.src,
            sandbox: '',
            loading: 'lazy',
          },
          children: [],
        },
      ],
    },
  ],
};

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
    local visit = invoke('visit', [$.visit]),
    local session = invoke('session', [$.session]),
    local addressOf = { [v.visitId]: v.address for v in session.visits },
    local parentIds = [edge.from for edge in session.edges if edge.to == $.visit],
    local childIds = [edge.to for edge in session.edges if edge.from == $.visit],
    local evaluations = visit.evaluations,
    data: {
      address: visit.address,
      versions: visit.versions,
      first: evaluations[0].timestamp,
      last: evaluations[std.length(evaluations) - 1].timestamp,
    },
    links: {
      course: {
        node: { _node: true, _queryPath: '/' + visit.address },
        session: root.arcourse.session($.session),
      },
    } + (
      if std.length(parentIds) > 0
      then {
        from: {
          [addressOf[parentIds[0]]]:
            root.arcourse.session($.session).visit(parentIds[0]),
        },
      }
      else {}
    ) + (
      if std.length(childIds) > 0
      then {
        next: {
          ['%02d %s' % [i + 1, addressOf[childIds[i]]]]:
            root.arcourse.session($.session).visit(childIds[i])
          for i in std.range(0, std.length(childIds) - 1)
        },
      }
      else {}
    ) + {
      versions: {
        ['%02d %s' % [i + 1, std.substr(evaluations[i].timestamp, 11, 8)]]:
          root.arcourse.session($.session).visit($.visit).evaluation(evaluations[i].evaluationId)
        for i in std.range(0, std.length(evaluations) - 1)
      },
    },
  }],
  [['arcourse', '$session', '$visit', '$evaluation'], a.resource.node + unrecorded {
    local evaluation = invoke('evaluation', [$.evaluation]),
    local evaluations = invoke('visit', [$.visit]).evaluations,
    local positions = [
      i
      for i in std.range(0, std.length(evaluations) - 1)
      if evaluations[i].evaluationId == $.evaluation
    ],
    local position = if std.length(positions) > 0 then positions[0] else -1,
    local adjacent = (
      if position > 0
      then {
        prev: root.arcourse.session($.session).visit($.visit)
              .evaluation(evaluations[position - 1].evaluationId),
      }
      else {}
    ) + (
      if position >= 0 && position < std.length(evaluations) - 1
      then {
        next: root.arcourse.session($.session).visit($.visit)
              .evaluation(evaluations[position + 1].evaluationId),
      }
      else {}
    ),
    data: {
      address: evaluation.address,
      timestamp: evaluation.timestamp,
      version: '%d of %d' % [position + 1, std.length(evaluations)],
    },
    links: {
      format: {
        html: $.html,
        json: $.json,
      },
      course: {
        node: { _node: true, _queryPath: '/' + evaluation.address },
        visit: root.arcourse.session($.session).visit($.visit),
        session: root.arcourse.session($.session),
      },
    } + (
      if std.length(adjacent) > 0
      then { versions: adjacent }
      else {}
    ),
    _view+:: {
      fragment: super.fragment {
        local yamlContent = super.content,
        content:: evaluationContent {
          content:: yamlContent,
          src:: $.html._queryPath,
        },
      },
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
