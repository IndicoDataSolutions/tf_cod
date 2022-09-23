output "cluster_manager_ip" {
  value = module.cluster-manager.cluster_manager_ip
}

output "storage_account_key" {
  sensitive = true
  value     = module.storage.storage_account_primary_access_key
}

output "indico_database_server_address" {
  value = module.database.indico_database_server_address
}

output "indico_database_server_fqdn" {
  value = module.database.indico_database_fqdn
}

output "indico_metrics_database_server_address" {
  value = module.metrics-database.indico_database_server_address
}

output "indico_metrics_database_server_fqdn" {
  value = module.metrics-database.indico_database_fqdn
}
