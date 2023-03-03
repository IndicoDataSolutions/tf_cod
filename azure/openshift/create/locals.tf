
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
  machinesets = flatten([
    for key, group in var.openshift_machine_sets : {
      name                           = key
      pool_name                      = group.pool_name
      vm_size                        = group.vm_size
      node_os                        = group.node_os
      zones                          = group.zones
      taints                         = group.taints
      labels                         = group.labels
      cluster_auto_scaling_min_count = group.cluster_auto_scaling_min_count
      cluster_auto_scaling_max_count = group.cluster_auto_scaling_max_count
      storageAccountType             = group.storageAccountType
      image                          = group.image
    }
  ])
  kube_prometheus_stack_enabled = false
  indico_storage_class_name     = "azurefile"
}
