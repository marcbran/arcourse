local telemetry = import '../arcourse-telemetry/main.libsonnet';

local deploymentStateTimeline = {
  local t = self,
  states:: {
    local replicas(metric, extra='') = 'max by (cluster, namespace, deployment) (%s{%s%s})' % [metric, t.matchers, extra],
    local state(name, expr) = 'label_replace(0 * (%s) + 1, "state", "%s", "", "")' % [expr, name],
    local desired = replicas('kube_deployment_spec_replicas'),
    local available = replicas('kube_deployment_status_replicas_available'),
    local updated = replicas('kube_deployment_status_replicas_updated'),
    local current = replicas('kube_deployment_status_replicas'),
    local paused = '(%s == 1)' % replicas('kube_deployment_spec_paused'),
    local stuck = '(%s == 1)' % replicas('kube_deployment_status_condition', ', condition="Progressing", status="false", reason="ProgressDeadlineExceeded"'),
    full: state('Full', '(%s >= %s) and (%s > 0)' % [available, desired, desired]),
    degraded: state('Degraded', '(%s > 0) < %s' % [available, desired]),
    down: state('Down', '(%s == 0) and (%s > 0)' % [available, desired]),
    scaledToZero: state('ScaledToZero', '%s == 0' % desired),
    settled: state('Settled', '((%s == %s) and (%s == %s)) unless %s unless %s' % [updated, desired, current, desired, paused, stuck]),
    rollingOut: state('RollingOut', '((%s < %s) or (%s > %s)) unless %s unless %s' % [updated, desired, current, desired, paused, stuck]),
    stuck: state('Stuck', '%s unless %s' % [stuck, paused]),
    paused: state('Paused', paused),
  },
  all:: error 'deploymentStateTimeline requires all',
  unhealthy:: error 'deploymentStateTimeline requires unhealthy',
  expr:: 'max by (%s, state) (%s)' % [self.groupBy, std.join(' or ', self.all)],
  colorBy:: '{{state}}',
  rowBy:: '{{deployment}}',
  labelBy:: '{{state}}',
  tooltip:: '{{deployment}} · {{state}} · {{from}} – {{to}}',
  levels:: {
    root: self.context,
    context: {
      expr:: 'count by (%s, state) (%s)' % [self.groupBy, std.join(' or ', self.unhealthy)],
      rowBy:: '{{%s}}: {{state}}' % self.groupBy,
      labelBy:: '{{value}}',
      tooltip:: '{{%s}} · {{state}}: {{value}} deployments · {{from}} – {{to}}' % self.groupBy,
    },
  },
};

{
  a:: telemetry,

  context:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context'],
    labels:: ['cluster'],
    entityPath:: ['kubernetes', '$context'],
    listExpr:: 'count by (%(groupBy)s) (kube_pod_info{%(matchers)s})' % self,
    logs:: {
      all: { expr:: '{cluster="%(context)s"}' % self },
      errors: { expr:: '{cluster="%(context)s"} | detected_level=~"error|critical|fatal"' % self },
    },
    drillDowns:: {},
  },

  namespace:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace'],
    labels:: ['cluster', 'namespace'],
    entityPath:: ['kubernetes', '$context', '$namespace'],
    listExpr:: 'count by (%(groupBy)s) (kube_pod_info{%(matchers)s}) or 0 * count by (%(groupBy)s) (kube_namespace_created{%(matchers)s})' % self,
    logs:: {
      all: { expr:: '{cluster="%(context)s", namespace="%(namespace)s"}' % self },
      errors: { expr:: '{cluster="%(context)s", namespace="%(namespace)s"} | detected_level=~"error|critical|fatal"' % self },
    },
    drillDowns:: {},
  },

  pod:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace', 'pod'],
    labels:: ['cluster', 'namespace', 'pod'],
    entityPath:: ['kubernetes', '$context', '$namespace', '$pod'],
    listExpr:: 'kube_pod_info{%(matchers)s}' % self,
    logs:: {
      all: { expr:: '{cluster="%(context)s", namespace="%(namespace)s"} | pod="%(pod)s"' % self },
      errors: { expr:: '{cluster="%(context)s", namespace="%(namespace)s"} | pod="%(pod)s" | detected_level=~"error|critical|fatal"' % self },
    },
    drillDowns:: {
      phase: $.a.promql.stateTimeline.chart {
        expr:: 'sum by (%(groupBy)s, phase) (kube_pod_status_phase{%(matchers)s}) > 0' % self,
        title:: 'Pod Phase %(titleGroupBy)s' % self,
        colorBy:: '{{phase}}',
        rowBy:: '{{namespace}}: {{phase}}',
        labelBy:: '{{value}}',
        tooltip:: '{{namespace}} · {{phase}}: {{value}} pods · {{from}} – {{to}}',
        colors:: {
          Running: '#5b8a5b',
          Pending: '#b0902f',
          Failed: '#a35454',
          Succeeded: '#5a7a94',
          Unknown: '#7a7a7a',
        },
        levels:: {
          root: self.context,
          context: {
            expr:: 'sum by (%(groupBy)s, phase) (kube_pod_status_phase{%(matchers)s, phase!="Running", phase!="Succeeded"}) > 0' % self,
            title:: 'Unhealthy Pod Phase %(titleGroupBy)s' % self,
          },
          namespace: self.pod,
          pod: {
            rowBy:: '{{pod}}',
            labelBy:: '{{phase}}',
            tooltip:: '{{pod}} · {{phase}} · {{from}} – {{to}}',
          },
        },
      },
    },
  },

  container:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace', 'pod', 'container'],
    labels:: ['cluster', 'namespace', 'pod', 'container'],
    listExpr:: 'container_memory_working_set_bytes{%(matchers)s, image!=""}' % self,
    logs:: {
      all: { expr:: '{cluster="%(context)s", namespace="%(namespace)s", container="%(container)s"} | pod="%(pod)s"' % self },
      errors: { expr:: '{cluster="%(context)s", namespace="%(namespace)s", container="%(container)s"} | pod="%(pod)s" | detected_level=~"error|critical|fatal"' % self },
    },
    drillDowns:: {
      restarts: $.a.promql.line.chart {
        expr::
          |||
            sum by (%(groupBy)s) (increase(kube_pod_container_status_restarts_total{%(matchers)s}[15m]))
          ||| % self,
        title:: 'Container Restarts %(titleGroupBy)s(15m)' % self,
      },
      cpu: $.a.promql.line.chart {
        expr:: 'sum by (%(groupBy)s) (rate(container_cpu_usage_seconds_total{%(matchers)s, image!=""}[5m]))' % self,
        title:: 'CPU Usage %(titleGroupBy)s(cores)' % self,
      },
      memory: $.a.promql.line.chart {
        expr:: 'sum by (%(groupBy)s) (container_memory_working_set_bytes{%(matchers)s, image!=""})' % self,
        title:: 'Memory Usage %(titleGroupBy)s' % self,
        unit:: 'bytes',
      },
    },
  },

  pvc:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace', 'pvc'],
    entityPath:: ['kubernetes', '$context', '$namespace', '$persistentvolumeclaim'],
    labels:: ['cluster', 'namespace', 'persistentvolumeclaim'],
    titles:: ['Context', 'Namespace', 'PVC'],
    listExpr:: 'kubelet_volume_stats_capacity_bytes{%(matchers)s}' % self,
    drillDowns:: {
      usage: $.a.promql.line.chart {
        expr::
          |||
            100 * sum by (%(groupBy)s) (kubelet_volume_stats_used_bytes{%(matchers)s})
            / sum by (%(groupBy)s) (kubelet_volume_stats_capacity_bytes{%(matchers)s})
          ||| % self,
        title:: 'PVC Usage (%%) %(titleGroupBy)s' % self,
      },
    },
  },

  deployment:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace', 'deployment'],
    entityPath:: ['kubernetes', '$context', '$namespace', 'apps', '$deployment'],
    labels:: ['cluster', 'namespace', 'deployment'],
    listExpr:: 'kube_deployment_spec_replicas{%(matchers)s}' % self,
    drillDowns:: {
      capacity: $.a.promql.stateTimeline.chart + deploymentStateTimeline {
        title:: 'Deployment Capacity %(titleGroupBy)s' % self,
        all:: [self.states.full, self.states.degraded, self.states.down, self.states.scaledToZero],
        unhealthy:: [self.states.degraded, self.states.down],
        colors:: {
          Full: '#5b8a5b',
          Degraded: '#b0902f',
          Down: '#a35454',
          ScaledToZero: '#7a7a7a',
        },
        levels+:: {
          context+: { title:: 'Unhealthy Deployment Capacity %(titleGroupBy)s' % self },
        },
      },
      rollout: $.a.promql.stateTimeline.chart + deploymentStateTimeline {
        title:: 'Deployment Rollout %(titleGroupBy)s' % self,
        all:: [self.states.settled, self.states.rollingOut, self.states.stuck, self.states.paused],
        unhealthy:: [self.states.rollingOut, self.states.stuck, self.states.paused],
        colors:: {
          Settled: '#5b8a5b',
          RollingOut: '#5a7a94',
          Stuck: '#a35454',
          Paused: '#7a7a7a',
        },
        levels+:: {
          context+: { title:: 'Deployment Rollouts %(titleGroupBy)s' % self },
        },
      },
    },
  },

  node:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'node'],
    labels:: ['cluster', 'node'],
    entityPath:: ['kubernetes', '$context', '$node'],
    listExpr:: 'count by (%(groupBy)s) (kube_node_info{%(matchers)s})' % self,
    drillDowns:: {
      conditions: $.a.promql.line.chart {
        expr::
          |||
            sum by (%(groupBy)s, condition, status) (kube_node_status_condition{%(matchers)s})
          ||| % self,
        title:: 'Node Conditions %(titleGroupBy)s' % self,
        legend:: '{{%(groupBy)s}}: {{condition}}: {{status}}' % self,
      },
    },
  },

  nodeList: $.a.promql.entities.nodeList([$.context, $.namespace, $.pod, $.container, $.pvc, $.deployment, $.node]),
}
