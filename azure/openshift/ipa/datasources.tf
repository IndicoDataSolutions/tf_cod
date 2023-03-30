
data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

data "azuread_service_principal" "redhat-openshift" {
  display_name = "Azure Red Hat OpenShift RP"
}

data "azuread_client_config" "current" {}


data "vault_kv_secret_v2" "zerossl_data" {
  mount = var.vault_mount_path
  name  = "zerossl"
}

data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "${var.github_organization}/${var.argo_repo}"
}
