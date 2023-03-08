locals {
  dns_name                = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}") # os1.eastus.indico-dev-azure.indico.io
  prometheus_address      = "http://monitoring-kube-prometheus-prometheus.${var.monitoring_namespace}.svc.cluster.local:9090/prometheus"
  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")

}

