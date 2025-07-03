#!/bin/bash

# Script to remove Vault-related resources from Terraform state
# This avoids manually running terraform state rm for each resource

echo "Removing Vault-related resources from Terraform state..."

# Vault data sources
terraform state rm -ignore-remote-version "data.vault_kv_secret_v2.harbor-api-token[0]" 2>/dev/null || echo "data.vault_kv_secret_v2.harbor-api-token[0] not found in state"
terraform state rm -ignore-remote-version "data.vault_kv_secret_v2.readapi_secret" 2>/dev/null || echo "data.vault_kv_secret_v2.readapi_secret not found in state"
terraform state rm -ignore-remote-version "data.vault_kv_secret_v2.zerossl_data" 2>/dev/null || echo "data.vault_kv_secret_v2.zerossl_data not found in state"

# Vault provider resources in secrets-operator-setup module
terraform state rm -ignore-remote-version "module.secrets-operator-setup[0].vault_auth_backend.kubernetes" 2>/dev/null || echo "module.secrets-operator-setup[0].vault_auth_backend.kubernetes not found in state"
terraform state rm -ignore-remote-version "module.secrets-operator-setup[0].vault_kubernetes_auth_backend_config.vault-auth" 2>/dev/null || echo "module.secrets-operator-setup[0].vault_kubernetes_auth_backend_config.vault-auth not found in state"
terraform state rm -ignore-remote-version "module.secrets-operator-setup[0].vault_kubernetes_auth_backend_role.vault-auth-role" 2>/dev/null || echo "module.secrets-operator-setup[0].vault_kubernetes_auth_backend_role.vault-auth-role not found in state"
terraform state rm -ignore-remote-version "module.secrets-operator-setup[0].vault_policy.vault-auth-policy" 2>/dev/null || echo "module.secrets-operator-setup[0].vault_policy.vault-auth-policy not found in state"

echo "Vault resource removal complete!"
echo ""
echo "Note: The following resources were NOT removed:"
echo "- AWS backup vault resource (module.s3-storage.module.bucket_create[0].aws_backup_vault.indico_data_backup_vault[0]) - This is an AWS resource, not Vault"
echo "- Kubernetes resources in the secrets-operator-setup module - These are still managed by Terraform:"
echo "  - module.secrets-operator-setup[0].kubernetes_cluster_role_binding.vault-auth"
echo "  - module.secrets-operator-setup[0].kubernetes_secret_v1.vault-auth-default"
echo "  - module.secrets-operator-setup[0].kubernetes_service_account_v1.vault-auth-default" 

