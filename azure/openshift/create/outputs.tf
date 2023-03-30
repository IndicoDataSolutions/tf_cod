

output "kubelet_identity" {
  value = {
    object_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
    client_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
  }
}

output "oidc_issuer_url" {
  value = "ERROR:OPENSHIFT-NOT-APPLICABLE"
}

output "id" {
  value = "ERROR:cluster.idOPENSHIFT-NOT-APPLICABLE"
}

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

output "openshift_console_url" {
  value = module.cluster.openshift_console_url
}

output "kubelet_identity_client_id" {
  value = module.cluster.kubelet_identity.client_id
}

output "kubelet_identity_object_id" {
  value = module.cluster.kubelet_identity.object_id
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "storage_account_id" {
  value = module.storage.storage_account_id
}

output "fileshare_name" {
  value = module.storage.fileshare_name
}

output "storage_account_primary_access_key" {
  value = module.storage.storage_account_primary_access_key
}

output "blob_store_name" {
  value = module.storage.blob_store_name
}
