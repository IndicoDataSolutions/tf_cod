# 
# Include modules only installed on AWS here.
#
module "keycloak" {
  depends_on = [
    module.cluster,
    helm_release.ipa-pre-requisites
  ]
  source         = "./modules/aws/keycloak"
  local_dns_name = local.dns_name
}

# Azure doesn't support arbitrary OIDC, so we can use keycloak on Azure.
module "k8s_dashboard" {
  count = var.enable_k8s_dashboard == true ? 1 : 0

  source = "./modules/aws/k8s_dashboard"

  local_dns_name         = local.dns_name
  ipa_repo               = var.ipa_repo
  keycloak_client_id     = module.keycloak.client_id
  keycloak_client_secret = module.keycloak.client_secret
}

resource "aws_eks_addon" "guardduty" {
  depends_on = [
    module.cluster
  ]
  count = var.eks_addon_version_guardduty != null ? 1 : 0
  

  cluster_name      = local.cluster_name
  addon_name        = "aws-guardduty-agent"
  addon_version     = "v1.2.0-eksbuild.1"
  resolve_conflicts = "OVERWRITE"

  preserve = true

  tags = {
    "eks_addon" = "guardduty"
  }
}