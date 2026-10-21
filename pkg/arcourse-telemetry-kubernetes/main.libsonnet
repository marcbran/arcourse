local telemetry = import '../arcourse-telemetry/main.libsonnet';

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
    listExpr:: 'count by (%(groupBy)s) (kube_pod_info{%(matchers)s})' % self,
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
    listExpr:: 'container_memory_working_set_bytes{%(matchers)s}' % self,
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
        expr:: 'sum by (%(groupBy)s) (rate(container_cpu_usage_seconds_total{%(matchers)s}[5m]))' % self,
        title:: 'CPU Usage %(titleGroupBy)s(cores)' % self,
      },
      memory: $.a.promql.line.chart {
        expr:: 'sum by (%(groupBy)s) (container_memory_working_set_bytes{%(matchers)s})' % self,
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
      availability: $.a.promql.line.chart {
        expr::
          |||
            sum by (%(groupBy)s) (kube_deployment_status_replicas_available{%(matchers)s})
            / sum by (%(groupBy)s) (kube_deployment_spec_replicas{%(matchers)s})
          ||| % self,
        title:: 'Deployment Availability %(titleGroupBy)s' % self,
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
