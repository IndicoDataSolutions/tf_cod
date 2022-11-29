# 
# Include local modules here
#
/*
module "k8s_dashboard" {
  #count = var.enable_k8s_dashboard == true ? 1 : 0

  #depends_on = [
  #  module.cluster,
  #  helm_release.ipa-pre-requisites
  #]

  source = "./modules/common/k8s_dashboard"

  local_dns_name       = local.dns_name
  enable_k8s_dashboard = var.enable_k8s_dashboard
  ipa_repo             = var.ipa_repo

}
*/
