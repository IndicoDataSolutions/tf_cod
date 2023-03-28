

locals {
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : lower("${var.label}-${var.region}")

  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")

  cluster_name = var.label
  dns_name     = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}")
  dns_prefix   = lower("${var.label}.${var.region}")
  base_domain  = lower("${var.account}.${var.domain_suffix}")

  kube_prometheus_stack_enabled = true

  indico_storage_class_name = "azurefile"


  monitoring_password = var.do_build_infrastructure == true ? module.infrastructure.0.monitoring_password : var.monitoring_password
  monitoring_username = var.do_build_infrastructure == true ? module.infrastructure.0.monitoring_username : var.monitoring_username

  cluster_oidc_issuer_url            = var.do_create_cluster == true ? module.create.0.oidc_issuer_url : var.cluster_oidc_issuer_url
  kubelet_identity_client_id         = var.do_create_cluster == true ? module.create.0.kubelet_identity.client_id : var.kubelet_identity_client_id
  kubelet_identity_object_id         = var.do_create_cluster == true ? module.create.0.kubelet_identity.object_id : var.kubelet_identity_object_id
  fileshare_name                     = var.do_create_cluster == true ? module.create.0.fileshare_name : var.fileshare_name
  storage_account_primary_access_key = var.do_create_cluster == true ? module.create.0.storage_account_primary_access_key : var.storage_account_primary_access_key
  blob_store_name                    = var.do_create_cluster == true ? module.create.0.blob_store_name : var.blob_store_name
  storage_account_name               = var.do_create_cluster == true ? module.create.0.storage_account_name : var.storage_account_name
  storage_account_id                 = var.do_create_cluster == true ? module.create.0.storage_account_id : var.storage_account_id
  kubeadmin_username                 = var.do_create_cluster == true ? module.create.0.kubeadmin_username : var.kubeadmin_username
  kubeadmin_password                 = var.do_create_cluster == true ? module.create.0.kubeadmin_password : var.kubeadmin_password
  kubernetes_host                    = var.do_create_cluster == true ? module.create.0.kubernetes_host : var.kubernetes_host
  kubernetes_client_certificate      = var.do_create_cluster == true ? module.create.0.kubernetes_client_certificate : var.kubernetes_client_certificate
  kubernetes_client_key              = var.do_create_cluster == true ? module.create.0.kubernetes_client_key : var.kubernetes_client_key
  kubernetes_cluster_ca_certificate  = var.do_create_cluster == true ? module.create.0.kubernetes_cluster_ca_certificate : var.kubernetes_cluster_ca_certificate
  openshift_console_url              = var.do_create_cluster == true ? module.create.0.openshift_console_url : var.openshift_console_url
}
