
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

  worker_subnet_cidrs = var.worker_subnet_cidrs

}
