# 
# Include modules only installed on AWS here.
#
module "keycloak" {
  depends_on = [
    module.cluster,
    helm_release.ipa-pre-requisites
  ]
  count          = var.keycloak_enabled == true ? 1 : 0
  source         = "./modules/aws/keycloak"
  local_dns_name = local.dns_name
}

# Azure doesn't support arbitrary OIDC, so we can use keycloak on Azure.
module "k8s_dashboard" {
  count = var.enable_k8s_dashboard == true && var.keycloak_enabled == true ? 1 : 0

  source = "./modules/aws/k8s_dashboard"

  local_dns_name         = local.dns_name
  ipa_repo               = var.ipa_repo
  keycloak_client_id     = module.keycloak[0].client_id
  keycloak_client_secret = module.keycloak[0].client_secret
}
