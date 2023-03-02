
data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

data "azuread_service_principal" "redhat-openshift" {
  display_name = "Azure Red Hat OpenShift RP"
}

data "azuread_client_config" "current" {}
