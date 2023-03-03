

locals {
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : lower("${var.label}.${var.region}")

  storage_account_name    = replace(lower("${var.account}snapshots"), "-", "")
  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")

  cluster_name = var.label
  base_domain  = lower("${var.account}.${var.domain_suffix}")
  dns_prefix   = lower("${var.label}.${var.region}")
  dns_name     = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}")

  kube_prometheus_stack_enabled = true

  indico_storage_class_name = "azurefile"

  kubeadmin_username                = var.do_create_cluster == true ? module.create.0.kubeadmin_username : var.kubeadmin_username
  kubeadmin_password                = var.do_create_cluster == true ? module.create.0.kubeadmin_password : var.kubeadmin_password
  kubernetes_host                   = var.do_create_cluster == true ? module.create.0.kubernetes_host : var.kubernetes_host
  kubernetes_client_certificate     = var.do_create_cluster == true ? module.create.0.kubernetes_client_certificate : var.kubernetes_client_certificate
  kubernetes_client_key             = var.do_create_cluster == true ? module.create.0.kubernetes_client_key : var.kubernetes_client_key
  kubernetes_cluster_ca_certificate = var.do_create_cluster == true ? module.create.0.kubernetes_cluster_ca_certificate : var.kubernetes_cluster_ca_certificate
}
