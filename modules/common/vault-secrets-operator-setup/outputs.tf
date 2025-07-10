
output "vault_mount_path" {
  value = local.account_region_name
}

output "vault_auth_role_name" {
  value = "vault-auth-role"
}

output "vault_auth_service_account_name" {
  value = kubernetes_service_account_v1.vault-auth-default.metadata.0.name
}

output "vault_auth_audience" {
  value = var.audience
}

