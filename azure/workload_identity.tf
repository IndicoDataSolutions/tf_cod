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

