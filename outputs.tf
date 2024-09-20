
output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = module.s3-storage[0].api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = module.s3-storage[0].data_s3_bucket_name
}

output "s3_role_id" {
  description = "ID of the S3 role"
  value       = module.cluster.s3_role_id
}


output "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  value       = var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""
}
output "fsx-rwx" {
  description = "Read write filesystem"
  value       = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx : null
}

output "fsx-rox" {
  description = "Read only filesystem"
  value       = var.include_rox ? module.fsx-storage[0].fsx-rox : ""
}

output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}

output "fsx_storage_fsx_rwx_dns_name" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.dns_name : ""
}

output "fsx_storage_fsx_rwx_mount_name" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.mount_name : ""
}

output "fsx_storage_fsx_rwx_volume_handle" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.id : ""
}

output "fsx_storage_fsx_rwx_subnet_id" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.subnet_ids[0] : ""
}

output "cluster_name" {
  value = var.label
}

output "cluster_region" {
  value = var.region
}

output "dns_name" {
  value = local.dns_name
}

# output "kubeconfig" {
#   value = module.cluster.kubectl_config
# }


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

output "harness_delegate_name" {
  value = var.harness_delegate == true && length(module.harness_delegate) > 0 ? module.harness_delegate[0].delegate_name : ""
}

output "ipa_version" {
  value = var.ipa_version
}

output "argo_branch" {
  value = var.argo_branch
}

output "argo_path" {
  value = var.argo_path
}

output "argo_repo" {
  value = var.argo_repo
}

output "monitoring_enabled" {
  value = var.monitoring_enabled
}