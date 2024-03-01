
data "azuread_group" "engineering" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  display_name     = var.ad_group_name
  security_enabled = true
}

resource "azuread_group" "cluster_admin" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  display_name     = "aks-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

# add engineering group to admins
resource "azuread_group_member" "engineering" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  group_object_id  = azuread_group.cluster_admin.id
  member_object_id = data.azuread_group.engineering.0.id
}

resource "azurerm_role_assignment" "cluster_admin" {
  count                = var.enable_ad_group_mapping == true ? 1 : 0
  scope                = module.cluster.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.cluster_admin.object_id
}

resource "azuread_group" "default_admin" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  display_name     = "aks-default-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_admin" {
  count                = var.enable_ad_group_mapping == true ? 1 : 0
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Admin"
  principal_id         = azuread_group.default_admin.object_id
}

resource "azuread_group" "default_write" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  display_name     = "aks-write-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_write" {
  count                = var.enable_ad_group_mapping == true ? 1 : 0
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_group.default_write.object_id
}

resource "azuread_group" "default_read" {
  count            = var.enable_ad_group_mapping == true ? 1 : 0
  display_name     = "aks-read-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_read" {
  count                = var.enable_ad_group_mapping == true ? 1 : 0
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azuread_group.default_read.object_id
}

resource "kubectl_manifest" "engineering-role-binding" {
  count = var.enable_ad_group_mapping == true ? 1 : 0
  depends_on = [
    module.cluster
  ]
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${lower(var.ad_group_name)}-team
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${data.azuread_group.engineering.0.object_id}
YAML
}
