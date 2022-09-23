
output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = module.s3-storage.api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = module.s3-storage.data_s3_bucket_name
}

output "cluster_manager_ip" {
  description = "IP of the cluster manager instance"
  value       = module.cluster-manager.cluster_manager_ip
}

output "fsx-rwx" {
  description = "Read write filesystem"
  value       = module.fsx-storage.fsx-rwx
}

output "fsx-rox" {
  description = "Read only filesystem"
  value       = module.fsx-storage.fsx-rox
}

output "indico_allow_access" {
  value       = aws_security_group.indico_allow_access.id
  description = "The ID of the indico indico_allow_access security group used for configuring HAproxy."
}

output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}

# Outputs for Argo
output "fsx_storage_fsx_rwx_dns_name" {
  value = module.fsx-storage.fsx-rwx.dns_name
}

output "fsx_storage_fsx_rwx_mount_name" {
  value = module.fsx-storage.fsx-rwx.mount_name
}

output "fsx_storage_fsx_rwx_volume_handle" {
  value = module.fsx-storage.fsx-rwx.id
}

output "fsx_storage_fsx_rwx_subnet_id" {
  value = module.fsx-storage.fsx-rwx.subnet_ids[0]
}

output "cluster_name" {
  value = local.cluster_name
}

output "dns_name" {
  value = local.dns_name
}

output "kubeconfig" {
  value = module.cluster.kubectl_config
}


output "kube_host" {
  value = module.cluster.kubernetes_host
}

output "kube_ca_certificate" {
  value = base64encode(module.cluster.kubernetes_cluster_ca_certificate)

}
output "kube_token" {
  sensitive = true
  value     = module.cluster.kubernetes_token
}
