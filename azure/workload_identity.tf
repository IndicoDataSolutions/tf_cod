data "azuread_client_config" "current" {}

resource "azuread_application" "workload_identity" {
  display_name = "${var.label}-${var.region}-workload-identity"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "workload_identity" {
  application_id               = azuread_application.workload_identity.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azurerm_role_assignment" "storage_account_role_assignment" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Owner"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "kubernetes_service_account" "workload_identity" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name = "workload_identity_storage_account"
    namespace = "default"
    annotations = {
      "azure.workload.identity/client-id" = azuread_application.workload_identity.object_id
    }
    labels = {
       "azure.workload.identity/use" = "true"
    }
  }
}

resource "azuread_application_federated_identity_credential" "workload_identity" {
  application_object_id = azuread_application.workload_identity.object_id
  display_name          = "${var.label}-${var.region}-workload-identity"
  description           = "Initial workload identity for cluster"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = module.cluster.oidc_issuer_url
  subject               = "system:serviceaccount:default:workload_identity_storage_account"
}

