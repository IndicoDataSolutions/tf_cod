# Cluster connection 
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

# EFS outputs
output "efs_filesystem_id" {
  value       = var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""
  description = "ID of the EFS filesystem"
}

output "local_registry_efs_filesystem_id" {
  value = var.local_registry_enabled ? module.efs-storage-local-registry[0].efs_filesystem_id : null
  description = "ID of the EFS filesystem for local-registry"
}

# FSX outputs
output "fsx-rwx" {
  description = "Read write filesystem"
  value       = var.include_fsx == true ? module.fsx-storage[0].fsx-rwx : null
}

output "fsx-rox" {
  description = "Read only filesystem"
  value       = var.include_rox ? module.fsx-storage[0].fsx-rox : ""
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

# S3 outputs
output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = module.s3-storage.api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = module.s3-storage.data_s3_bucket_name
}

output "s3_role_id" {
  description = "ID of the S3 role"
  value       = module.cluster.s3_role_id
}

# Misc
output "acm_arn" {
  description = "arn of the acm"
  value       = var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : ""
}

output "wafv2_arn" {
  description = "arn of the wafv2 acl"
  value       = var.enable_waf == true ? aws_wafv2_web_acl.wafv2-acl[0].arn : ""
}

output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}
