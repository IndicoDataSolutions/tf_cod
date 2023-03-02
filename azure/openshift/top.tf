
module "create" {
  count  = var.do_create_cluster == true ? 1 : 0
  source = "./create"

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
  count  = var.do_build_infrastructure == true ? 1 : 0
  source = "./infrastructure"

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


module "ipa" {
  count  = var.do_deploy_ipa == true ? 1 : 0
  source = "./ipa"

  label                              = var.label
  region                             = var.region
  domain                             = var.domain
  domain_suffix                      = var.domain_suffix
  account                            = var.account
  k8s_version                        = var.k8s_version
  cluster_type                       = "openshift-azure"
  argo_enabled                       = var.argo_enabled
  github_organization                = var.github_organization
  argo_repo                          = var.argo_repo
  argo_branch                        = var.argo_branch
  argo_path                          = var.argo_path
  commit_message                     = var.message
  storage_key_secret                 = module.infrastructure.0.storage_key_secret
  harbor_pull_secret                 = var.harbor_pull_secret
  kubelet_identity_client_id         = module.create.0.kubelet_identity_client_id
  kubelet_identity_object_id         = module.create.0.kubelet_identity_object_id
  storage_account_name               = module.create.0.storage_account_name
  fileshare_name                     = module.create.0.fileshare_name
  storage_account_primary_access_key = module.create.0.storage_account_primary_access_key
  blob_store_name                    = module.create.0.blob_store_name
}

module "ipa-testing" {
  count  = var.do_test_ipa == true ? 1 : 0
  source = "./ipa-testing"

  label                          = var.label
  region                         = var.region
  account                        = var.account
  domain                         = var.domain
  k8s_version                    = var.k8s_version
  github_organization = 
  ipa_smoketest_repo             = var.ipa_smoketest_repo
  ipa_smoketest_version          = var.ipa_smoketest_version
  ipa_smoketest_values           = var.ipa_smoketest_values
  ipa_smoketest_container_tag    = var.ipa_smoketest_container_tag
  ipa_smoketest_cronjob_enabled  = var.ipa_smoketest_cronjob_enabled
  ipa_smoketest_cronjob_schedule = var.ipa_smoketest_cronjob_schedule
  ipa_smoketest_slack_channel    = var.ipa_smoketest_slack_channel
}
