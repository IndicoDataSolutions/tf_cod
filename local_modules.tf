# 
# Include local modules here
#
module "keycloak" {  
  depends_on = [
    module.cluster,
    helm_release.ipa-pre-requisites
  ]
  source = "./modules/common/keycloak"
}

module "k8s_dashboard" {
  count = var.enable_k8s_dashboard == true ? 1 : 0

  source = "./modules/common/k8s_dashboard"

  local_dns_name         = local.dns_name
  ipa_repo               = var.ipa_repo
  keycloak_client_id     =  module.keycloak.client_id
  keycloak_client_secret =  module.keycloak.client_secret
}
