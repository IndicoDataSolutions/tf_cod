
locals {
  nfd_namespace             = var.nfd_namespace
  nvidia_operator_namespace = var.nvidia_operator_namespace
  package                   = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
  channel                   = data.kubernetes_resource.package.object.status.defaultChannel
}
