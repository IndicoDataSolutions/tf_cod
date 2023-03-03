
locals {
  nfd_namespace             = "openshift-nfd"
  nvidia_operator_namespace = var.nvidia_operator_namespace
  package                   = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
  channel                   = data.kubernetes_resource.package.object.status.defaultChannel
}
