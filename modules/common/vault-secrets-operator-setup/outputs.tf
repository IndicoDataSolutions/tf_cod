
output "vault_mount_path" {
  value = local.account_region_name
}

output "vault_auth_role_name" {
  value = vault_kubernetes_auth_backend_role.vault-auth-role.role_name
}

output "vault_auth_service_account_name" {
  value = kubernetes_service_account_v1.vault-auth.metadata.0.name
}

output "vault_auth_audience" {
  value = var.audience
}

