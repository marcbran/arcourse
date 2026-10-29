local telemetry = import '../arcourse-telemetry/main.libsonnet';

local workloadStateTimeline = {
  local t = self,
  local labelled(name, expr) = 'label_replace(0 * (%s) + 1, "state", "%s", "", "")' % [expr, name],
  workload:: error 'workloadStateTimeline requires workload',
  workloadTitle:: error 'workloadStateTimeline requires workloadTitle',
  desiredMetric:: error 'workloadStateTimeline requires desiredMetric',
  series(metric, extra=''):: 'max by (cluster, namespace, %s) (%s{%s%s})' % [t.workload, metric, t.matchers, extra],
  desired:: t.series(t.desiredMetric),
  conditions:: error 'workloadStateTimeline requires conditions',
  states:: error 'workloadStateTimeline requires states',
  unhealthy:: error 'workloadStateTimeline requires unhealthy',
  expr:: 'max by (%s, state) (%s)' % [t.groupBy, std.join(' or ', [labelled(s, t.conditions[s]) for s in t.states])],
  colorBy:: '{{state}}',
  rowBy:: '{{%s}}' % t.workload,
  labelBy:: '{{state}}',
  tooltip:: '{{%s}} · {{state}} · {{from}} – {{to}}' % t.workload,
  levels:: {
    root: self.context,
    context: {
      expr:: 'count by (%s, state) (%s)' % [self.groupBy, std.join(' or ', [labelled(s, self.conditions[s]) for s in self.unhealthy])],
      rowBy:: '{{%s}}: {{state}}' % self.groupBy,
      labelBy:: '{{value}}',
      tooltip:: '{{%s}} · {{state}}: {{value}} %ss · {{from}} – {{to}}' % [self.groupBy, self.workload],
    },
  },
};

local capacityTimeline = workloadStateTimeline {
  local t = self,
  local available = '(%s or %s)' % [
    t.series('kube_%s_status_replicas_available' % t.workload),
    t.series('kube_%s_status_replicas_ready' % t.workload),
  ],
  local heldDesired = 'max by (cluster, namespace, %s) (min_over_time(%s{%s}[5m]))' % [t.workload, t.desiredMetric, t.matchers],
  title:: '%s Capacity %s' % [t.workloadTitle, t.titleGroupBy],
  states:: ['Full', 'ScalingUp', 'Degraded', 'Down', 'ScaledToZero'],
  unhealthy:: ['Degraded', 'Down'],
  conditions:: {
    Full: '(%s >= %s) and (%s > 0)' % [available, t.desired, t.desired],
    ScalingUp: '(%s >= %s) < %s' % [available, heldDesired, t.desired],
    Degraded: '(%s > 0) < %s' % [available, heldDesired],
    Down: '(%s == 0) and (%s > 0)' % [available, heldDesired],
    ScaledToZero: '%s == 0' % t.desired,
  },
  colors:: {
    Full: '#5b8a5b',
    ScalingUp: '#5a7a94',
    Degraded: '#b0902f',
    Down: '#a35454',
    ScaledToZero: '#7a7a7a',
  },
  levels+:: {
    context+: { title:: 'Unhealthy %s Capacity %s' % [self.workloadTitle, self.titleGroupBy] },
  },
};

local deploymentWorkload = {
  workload:: 'deployment',
  workloadTitle:: 'Deployment',
  desiredMetric:: 'kube_deployment_spec_replicas',
};

local statefulsetWorkload = {
  workload:: 'statefulset',
  workloadTitle:: 'StatefulSet',
  desiredMetric:: 'kube_statefulset_replicas',
};

local deploymentRolloutTimeline = workloadStateTimeline + deploymentWorkload {
  local t = self,
  local updated = t.series('kube_deployment_status_replicas_updated'),
  local current = t.series('kube_deployment_status_replicas'),
  local paused = '(%s == 1)' % t.series('kube_deployment_spec_paused'),
  local stuck = '(%s == 1)' % t.series('kube_deployment_status_condition', ', condition="Progressing", status="false", reason="ProgressDeadlineExceeded"'),
  title:: 'Deployment Rollout %s' % t.titleGroupBy,
  states:: ['Settled', 'RollingOut', 'Stuck', 'Paused'],
  unhealthy:: ['Stuck'],
  conditions:: {
    Settled: '((%s == %s) and (%s == %s)) unless %s unless %s' % [updated, t.desired, current, t.desired, paused, stuck],
    RollingOut: '((%s < %s) or (%s > %s)) unless %s unless %s' % [updated, t.desired, current, t.desired, paused, stuck],
    Stuck: '%s unless %s' % [stuck, paused],
    Paused: paused,
  },
  colors:: {
    Settled: '#5b8a5b',
    RollingOut: '#5a7a94',
    Stuck: '#a35454',
    Paused: '#7a7a7a',
  },
  levels+:: {
    context+: { title:: 'Stuck Deployment Rollouts %s' % self.titleGroupBy },
  },
};

local statefulsetRolloutTimeline = workloadStateTimeline + statefulsetWorkload {
  local t = self,
  local outdated = 'max by (cluster, namespace, statefulset) (kube_statefulset_status_update_revision{%s} unless on (cluster, namespace, statefulset, revision) kube_statefulset_status_current_revision{%s})' % [t.matchers, t.matchers],
  title:: 'StatefulSet Rollout %s' % t.titleGroupBy,
  hidden:: ['root', 'context'],
  states:: ['Settled', 'Outdated'],
  unhealthy:: [],
  conditions:: {
    Settled: '%s unless on (cluster, namespace, statefulset) %s' % [t.desired, outdated],
    Outdated: outdated,
  },
  colors:: {
    Settled: '#5b8a5b',
    Outdated: '#5a7a94',
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
      capacity: $.a.promql.stateTimeline.chart + capacityTimeline + deploymentWorkload,
      rollout: $.a.promql.stateTimeline.chart + deploymentRolloutTimeline,
    },
  },

  statefulset:: {
    base:: ['telemetry', 'kubernetes'],
    vars:: ['context', 'namespace', 'statefulset'],
    entityPath:: ['kubernetes', '$context', '$namespace', 'apps', '$statefulset'],
    labels:: ['cluster', 'namespace', 'statefulset'],
    titles:: ['Context', 'Namespace', 'StatefulSet'],
    listExpr:: 'kube_statefulset_replicas{%(matchers)s}' % self,
    drillDowns:: {
      capacity: $.a.promql.stateTimeline.chart + capacityTimeline + statefulsetWorkload,
      rollout: $.a.promql.stateTimeline.chart + statefulsetRolloutTimeline,
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

  nodeList: $.a.promql.entities.nodeList([$.context, $.namespace, $.pod, $.container, $.pvc, $.deployment, $.statefulset, $.node]),
}
