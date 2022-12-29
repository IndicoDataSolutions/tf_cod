
data "azuread_group" "engineering" {
  display_name     = "Engineering"
  security_enabled = true
}

resource "azuread_group" "cluster_admin" {
  display_name     = "aks-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

# add engineering group to admins
resource "azuread_group_member" "engineering" {
  group_object_id  = azuread_group.cluster_admin.id
  member_object_id = data.azuread_user.engineering.id
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
  principal_id         = azuread_group.default_admin.object_id
}

resource "azuread_group" "default_write" {
  display_name     = "aks-write-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_write" {
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_group.default_write.object_id
}

resource "azuread_group" "default_read" {
  display_name     = "aks-read-admin-${var.label}-${var.region}"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "default_read" {
  scope                = "${module.cluster.id}/namespaces/default"
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azuread_group.default_read.object_id
}

resource "kubectl_manifest" "engineering-role-binding" {
  depends_on = [
    module.cluster
  ]
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: engineering-team
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${data.azuread_group.engineering.object_id}
YAML
}
