variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}
variable "kubernetes_host" {}
variable "audience" {
  default = "vault"
}

locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}

output "vault_mount_path" {
  value = local.account_region_name
}


output "vault_auth_role_name" {
  value = vault_kubernetes_auth_backend_role.vault-auth-role.role_name
}


output "vault_auth_service_account_name" {
  value = kubernetes_service_account_v1.vault-auth.metadata.0.name
}



output "vault_auth_audiences" {
  value = [var.audience]
}

