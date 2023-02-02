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

resource "azurerm_role_assignment" "dns-zone-contributor" {
  scope                = data.azurerm_dns_zone.domain.id
  role_definition_name = "Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azurerm_role_assignment" "dns-zone-dns-zone-contributor" {
  scope                = data.azurerm_dns_zone.domain.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azuread_application_password" "workload_identity" {
  display_name          = "workload_identity"
  application_object_id = azuread_application.workload_identity.object_id
}

resource "kubernetes_secret" "workload_identity" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name = "workload-identity"
  }

  data = {
    ARM_SUBSCRIPTION_ID = "${data.azurerm_subscription.primary.subscription_id}"
    ARM_TENANT_ID       = "${data.azuread_client_config.current.tenant_id}"
    ARM_CLIENT_ID       = "${azuread_application.workload_identity.application_id}"
    ARM_CLIENT_SECRET   = "${azuread_application_password.workload_identity.value}"
  }

  type = "Opaque"
}


resource "azurerm_role_assignment" "blob_storage_account_owner" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Owner"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azurerm_role_assignment" "blob_storage_account_blob_contributer" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azurerm_role_assignment" "blob_storage_account_queue_contributer" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

# Add snapshot permissions to the sp that is mounted as workload identity into the cluster
data "azurerm_storage_account" "snapshot" {
  name                = replace(lower("${var.account}snapshots"), "-", "")
  resource_group_name = "indico-common"
}

resource "azurerm_role_assignment" "snapshot_storage_account_owner" {
  scope                = data.azurerm_storage_account.snapshot.id
  role_definition_name = "Owner"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azurerm_role_assignment" "snapshot_storage_account_blob_contributer" {
  scope                = data.azurerm_storage_account.snapshot.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "azurerm_role_assignment" "snapshot_storage_account_queue_contributer" {
  scope                = data.azurerm_storage_account.snapshot.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = resource.azuread_service_principal.workload_identity.object_id
}

resource "kubernetes_service_account" "workload_identity" {
  count = var.use_workload_identity == true ? 1 : 0
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "workload-identity-storage-account"
    namespace = "default"
    annotations = {
      "azure.workload.identity/client-id" = azuread_application.workload_identity.application_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}

resource "azuread_application_federated_identity_credential" "workload_identity" {
  count                 = var.use_workload_identity == true ? 1 : 0
  application_object_id = azuread_application.workload_identity.object_id
  display_name          = "${var.label}-${var.region}-workload-identity"
  description           = "Initial workload identity for cluster"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = module.cluster.oidc_issuer_url
  subject               = "system:serviceaccount:default:workload-identity-storage-account"
}


resource "azuread_application_federated_identity_credential" "workload_snapshot_identity" {
  count                 = var.use_workload_identity == true ? 1 : 0
  application_object_id = azuread_application.workload_identity.object_id
  display_name          = "${var.label}-${var.region}-workload-snapshot-identity"
  description           = "Initial workload snapshot identity for cluster"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = module.cluster.oidc_issuer_url
  subject               = "system:serviceaccount:default:cod-snapshots"
}
