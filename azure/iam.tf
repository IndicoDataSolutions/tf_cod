resource "azuread_group" "cluster_admin" {
  display_name     = "aks-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "cluster_admin" {
  scope                = module.cluster.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.cluster_admin.object_id
}

resource "azuread_group" "default_admin" {
  display_name     = "aks-default-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_admin" {
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Admin"
  principal_id         = azuread_group.cluster_admin.default_admin
}

resource "azuread_group" "default_write" {
  display_name     = "aks-write-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_write" {
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_group.cluster_admin.default_write
}

resource "azuread_group" "default_read" {
  display_name     = "aks-read-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_read" {
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azuread_group.cluster_admin.default_read
}
