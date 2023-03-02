

output "kubernetes_host" {
  value = module.cluster.kubernetes_host
}

output "kubeadmin_username" {
  value = module.cluster.kubeadmin_username
}


output "kubeadmin_password" {
  value = module.cluster.kubeadmin_password
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

output "openshift_api_server_ip" {
  value = module.cluster.openshift_api_server_ip
}

output "openshift_console_ip" {
  value = module.cluster.openshift_console_ip
}



