
output "workload_identity_client_id" {
  value = azuread_application.workload_identity.application_id
}

output "kubernetes_host" {
  value = module.cluster.kubernetes_host
}


output "kubernetes_url" {
  value = module.cluster.kubernetes_url
}

output "sa_username" {
  value = module.cluster.kubernetes_sa_username
}

output "sa_token" {
  value = module.cluster.kubernetes_sa_token
}

output "kubernetes_token" {
  value = module.cluster.kubernetes_token
}


output "credentials" {
  value = module.cluster.credentials
}


#  Now, we get back the output of the script
output "kubernetes_username" {
  value = module.cluster.kubernetes_username
}

output "kubernetes_password" {
  value = module.cluster.kubernetes_password
}

output "kubernetes_ca_cert" {
  value = module.cluster.kubernetes_sa_cert
}

output "api_server_ip" {
  value = module.cluster.api_server_ip
}

output "console_ingress_ip" {
  value = module.cluster.console_ingress_ip
}

