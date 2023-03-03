
locals {
  nfd_namespace             = var.nfd_namespace
  nvidia_operator_namespace = var.nvidia_operator_namespace
  package                   = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
  channel                   = data.kubernetes_resource.package.object.status.defaultChannel
  infrastructure_id         = data.kubernetes_resource.infrastructure-cluster.object.status.infrastructureName
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

}
