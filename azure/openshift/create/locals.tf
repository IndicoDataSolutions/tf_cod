
locals {
  resource_group_name     = "${var.label}-${var.region}"
  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")
  cluster_name            = var.label
  base_domain             = lower("${var.account}.${var.domain_suffix}")                            # indico-dev-azure.indico.io
  dns_prefix              = lower("${var.label}.${var.region}")                                     # os1.eastus
  dns_name                = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}") # os1.eastus.indico-dev-azure.indico.io
  infrastructure_id       = data.kubernetes_resource.infrastructure-cluster.object.status.infrastructureName

  kube_prometheus_stack_enabled = false
  indico_storage_class_name     = "azurefile"
}
