output "cluster_manager_ip" {
  value = module.cluster-manager.cluster_manager_ip
}

output "workload_identity_client_id" {
  value = azuread_application.workload_identity.application_id
}
