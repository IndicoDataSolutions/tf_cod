
output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = module.infra.api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = module.infra.data_s3_bucket_name
}

output "s3_role_id" {
  description = "ID of the S3 role"
  value       = module.infra.s3_role_id
}


output "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  value       = module.infra.efs_filesystem_id
}

output "fsx-rwx" {
  description = "Read write filesystem"
  value       = module.infra.fsx-rwx
}

output "fsx-rox" {
  description = "Read only filesystem"
  value       = module.infra.fsx-rox
}

output "key_pem" {
  value       = module.infra.key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}

output "fsx_storage_fsx_rwx_dns_name" {
  value = module.infra.fsx_storage_fsx_rwx_dns_name
}

output "fsx_storage_fsx_rwx_mount_name" {
  value = module.infra.fsx_storage_fsx_rwx_mount_name
}

output "fsx_storage_fsx_rwx_volume_handle" {
  value = module.infra.fsx_storage_fsx_rwx_volume_handle
}

output "fsx_storage_fsx_rwx_subnet_id" {
  value = module.infra.fsx_storage_fsx_rwx_subnet_id
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
  value = module.infra.kube_host
}

output "kube_ca_certificate" {
  value = module.infra.kube_ca_certificate

}
output "kube_token" {
  sensitive = true
  value     = module.infra.kube_token
}

#output "harness_delegate_name" {
#  value = var.harness_delegate == true && length(module.harness_delegate) > 0 ? module.harness_delegate[0].delegate_name : ""
#}

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


#output "harbor-api-token" {
#  sensitive = true
#  value     = var.argo_enabled == true ? jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"] : ""
#}
