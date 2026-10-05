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

local executionItem = {
  local c = self,
  node:: error 'ExecutionItem requires a node',
  html: [
    {
      element: 'a',
      attributes: { href: c.node.link },
      children: ['execution'],
    },
    {
      element: 'span',
      attributes: { class: 'detail' },
      children: ['%s %s' % [c.node.time, c.node.status]],
    },
  ],
};

local courseItem = {
  local c = self,
  node:: error 'CourseItem requires a node',
  html: (if c.node.kind == 'execution' then executionItem else visitItem) { node:: c.node }.html,
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
    local session = root.arcourse.session($.session),
    local visitIds = { [visit.visitId]: true for visit in $.data.visits },
    local executionIds = { [execution.executionId]: true for execution in $.data.executions },
    local branches(visits, executions) = [
      entry.branch
      for entry in std.sort(
        [{ timestamp: visit.timestamp, branch: visitBranch(visit) } for visit in visits] +
        [{ timestamp: execution.timestamp, branch: executionBranch(execution) } for execution in executions],
        function(entry) entry.timestamp,
      )
    ],
    local visitBranch(visit) = {
      kind: 'visit',
      address: visit.address,
      time: std.substr(visit.timestamp, 11, 8),
      link: session.visit(visit.visitId)._queryPath,
      children: branches(
        [child for child in $.data.visits if child.parent.visit == visit.visitId],
        [execution for execution in $.data.executions if execution.visitId == visit.visitId],
      ),
    },
    local executionBranch(execution) = {
      kind: 'execution',
      status: execution.status,
      time: std.substr(execution.timestamp, 11, 8),
      link: session.execution(execution.executionId)._queryPath,
      children: branches(
        [child for child in $.data.visits if child.parent.execution == execution.executionId],
        [],
      ),
    },
    tree:: {
      nodes: branches(
        [
          visit
          for visit in $.data.visits
          if !std.objectHas(visitIds, visit.parent.visit)
             && !std.objectHas(executionIds, visit.parent.execution)
        ],
        [
          execution
          for execution in $.data.executions
          if !std.objectHas(visitIds, execution.visitId)
        ],
      ),
      item: courseItem,
    },
  }],
  [['arcourse', '$session', '$visit'], a.resource.node + unrecorded {
    local visit = invoke('visit', [$.visit]),
    local session = invoke('session', [$.session]),
    local sessionNode = root.arcourse.session($.session),
    local visitOf = { [v.visitId]: v for v in session.visits },
    local parent = std.get(visitOf, $.visit, { parent: { visit: '', execution: '' } }).parent,
    local childIds = [v.visitId for v in session.visits if v.parent.visit == $.visit],
    local evaluations = visit.evaluations,
    local executions = visit.executions,
    data: {
      address: visit.address,
      versions: visit.versions,
      first: evaluations[0].timestamp,
      last: evaluations[std.length(evaluations) - 1].timestamp,
    },
    links: {
      course: {
        node: { _node: true, _queryPath: '/' + visit.address },
        session: sessionNode,
      },
    } + (
      if std.objectHas(visitOf, parent.visit)
      then { from: { [visitOf[parent.visit].address]: sessionNode.visit(parent.visit) } }
      else if parent.execution != ''
      then { from: { execution: sessionNode.execution(parent.execution) } }
      else {}
    ) + (
      if std.length(childIds) > 0
      then {
        next: {
          ['%02d %s' % [i + 1, visitOf[childIds[i]].address]]:
            sessionNode.visit(childIds[i])
          for i in std.range(0, std.length(childIds) - 1)
        },
      }
      else {}
    ) + (
      if std.length(executions) > 0
      then {
        executions: {
          ['%02d %s %s' % [i + 1, std.substr(executions[i].timestamp, 11, 8), executions[i].status]]:
            sessionNode.execution(executions[i].executionId)
          for i in std.range(0, std.length(executions) - 1)
        },
      }
      else {}
    ) + {
      versions: {
        ['%02d %s' % [i + 1, std.substr(evaluations[i].timestamp, 11, 8)]]:
          sessionNode.visit($.visit).evaluation(evaluations[i].evaluationId)
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
  [['arcourse', '$session', '$execution'], a.resource.node + unrecorded {
    local execution = invoke('execution', [$.execution]),
    local session = invoke('session', [$.session]),
    local sessionNode = root.arcourse.session($.session),
    local content = std.parseJson(invoke('content', [execution.from, 'json'])),
    local visitOf = { [v.visitId]: v for v in session.visits },
    local nextIds = [v.visitId for v in session.visits if v.parent.execution == $.execution],
    data: {
      address: execution.address,
      action: std.get(content, '_action', {}),
      status: execution.status,
      started: execution.timestamp,
    } + (
      if execution.finished != '' then { finished: execution.finished } else {}
    ) + (
      if execution['error'] != '' then { 'error': execution['error'] } else {}
    ),
    links: {
      course: {
        node: { _node: true, _queryPath: '/' + execution.address },
        evaluation: sessionNode.visit(execution.visitId).evaluation(execution.from),
        visit: sessionNode.visit(execution.visitId),
        session: sessionNode,
      },
    } + (
      if execution.hasOutput then { content: { output: $.output } } else {}
    ) + (
      if std.length(nextIds) > 0
      then {
        next: {
          ['%02d %s' % [i + 1, visitOf[nextIds[i]].address]]:
            sessionNode.visit(nextIds[i])
          for i in std.range(0, std.length(nextIds) - 1)
        },
      }
      else {}
    ),
  }],
  [['arcourse', '$session', '$execution', 'output'], a.yaml.node + unrecorded {
    data: { output: invoke('output', [$.execution]) },
  }],
]
