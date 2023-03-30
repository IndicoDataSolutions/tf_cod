locals {
  argo_app_name = lower("${var.account}.${var.region}.${var.label}-ipa")

  prometheus_address = "http://monitoring-kube-prometheus-prometheus.${var.monitoring_namespace}.svc.cluster.local:9090/prometheus"
}

