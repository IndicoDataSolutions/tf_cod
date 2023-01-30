
output "workload_identity_client_id" {
  value = azuread_application.workload_identity.application_id
}

#  Now, we get back the output of the script
output "kubernetes_host" {
  value = module.cluster.kubernetes_host
}

output "kubernetes_client_certificate" {
  value = module.cluster.kubernetes_client_certificate
}

output "kubernetes_client_key" {
  value = module.cluster.kubernetes_client_key
}

output "kubernetes_cluster_ca_certificate" {
  value = module.cluster.kubernetes_cluster_ca_certificate
}

