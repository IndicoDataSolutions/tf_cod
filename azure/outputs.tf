output "cluster_manager_ip" {
  value = module.cluster-manager.cluster_manager_ip
}
  
output "cluster_manager_key" {
  value = tls_private_key.pk.public_key_openssh 
}

output "terraform_ip" {
  value = local.current_ip
}

output "workload_identity_client_id" {
  value = azuread_application.workload_identity.application_id
}
