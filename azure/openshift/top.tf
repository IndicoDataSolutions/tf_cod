
module "create" {
  count  = var.do_create_cluster == true ? 1 : 0
  source = "./create"

  resource_group_name    = local.resource_group_name
  vault_username         = var.vault_username
  vault_password         = var.vault_password
  subnet_cidrs           = var.subnet_cidrs
  vnet_cidr              = var.vnet_cidr
  svp_client_id          = var.svp_client_id
  svp_client_secret      = var.svp_client_secret
  harbor_pull_secret_b64 = var.harbor_pull_secret_b64
  openshift_pull_secret  = var.openshift_pull_secret
  openshift_machine_sets = var.openshift_machine_sets
  openshift_version      = var.openshift_version
  worker_subnet_cidrs    = var.worker_subnet_cidrs
}


module "infrastructure" {
  depends_on = [
    module.create
  ]
  count  = var.do_build_infrastructure == true ? 1 : 0
  source = "./infrastructure"

  resource_group_name = local.resource_group_name
  label               = var.label
  region              = var.region

  enable_dns_infrastructure        = var.enable_dns_infrastructure
  enable_gpu_infrastructure        = var.enable_gpu_infrastructure
  enable_monitoring_infrastructure = var.enable_monitoring_infrastructure

  common_resource_group     = var.common_resource_group
  base_domain               = local.base_domain
  dns_prefix                = local.dns_prefix
  nvidia_operator_namespace = var.nvidia_operator_namespace
}
/*

module "ipa" {
  depends_on = [
    module.create,
    module.infrastructure
  ]

  count  = var.do_deploy_ipa == true ? 1 : 0
  source = "./ipa"

  label                              = var.label
  region                             = var.region
  account                            = var.account
  domain_suffix                      = var.domain_suffix
  k8s_version                        = var.k8s_version
  cluster_type                       = "openshift-azure"
  argo_enabled                       = var.argo_enabled
  github_organization                = var.github_organization
  ipa_repo                           = var.ipa_repo
  ipa_crds_version                   = var.ipa_crds_version
  ipa_pre_reqs_version               = var.ipa_pre_reqs_version
  argo_repo                          = var.argo_repo
  argo_branch                        = var.argo_branch
  argo_path                          = var.argo_path
  commit_message                     = var.message
  storage_key_secret                 = module.infrastructure.0.storage_key_secret
  harbor_pull_secret_b64             = var.harbor_pull_secret_b64
  kubernetes_host                    = local.kubernetes_host
  kubelet_identity_client_id         = local.kubelet_identity_client_id
  kubelet_identity_object_id         = local.kubelet_identity_object_id
  storage_account_name               = local.storage_account_name
  fileshare_name                     = local.fileshare_name
  storage_account_primary_access_key = local.storage_account_primary_access_key
  blob_store_name                    = local.blob_store_name
  applications                       = var.applications
}

module "ipa-testing" {
  depends_on = [
    module.create,
    module.infrastructure,
    module.ipa
  ]

  count                          = var.do_test_ipa == true ? 1 : 0
  source                         = "./ipa-testing"
  kubernetes_host                = local.kubernetes_host
  label                          = var.label
  region                         = var.region
  account                        = var.account
  domain_suffix                  = var.domain_suffix
  k8s_version                    = var.k8s_version
  github_organization            = var.github_organization
  ipa_smoketest_repo             = var.ipa_smoketest_repo
  ipa_smoketest_version          = var.ipa_smoketest_version
  ipa_smoketest_values           = var.ipa_smoketest_values
  ipa_smoketest_container_tag    = var.ipa_smoketest_container_tag
  ipa_smoketest_cronjob_enabled  = var.ipa_smoketest_cronjob_enabled
  ipa_smoketest_cronjob_schedule = var.ipa_smoketest_cronjob_schedule
  ipa_smoketest_slack_channel    = var.ipa_smoketest_slack_channel
}
*/
