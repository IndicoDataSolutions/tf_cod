output "cluster_manager_ip" {
  value = module.cluster-manager.cluster_manager_ip
}

output "storage_account_key" {
  sensitive = true
  value     = module.file-storage.storage_account_primary_access_key
}

