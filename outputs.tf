
output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = module.s3-storage.api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = module.s3-storage.data_s3_bucket_name
}

output "pgbackup_s3_bucket_name" {
  description = "Name of the pgbackup s3 bucket"
  value       = module.s3-storage.pgbackup_s3_bucket_name
}

output "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  value       = var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""
}
output "fsx_rwx_id" {
  description = "Read write filesystem"
  value       = var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : null
}

output "fsx_rox_id" {
  description = "Read only filesystem"
  value       = var.include_rox ? module.fsx-storage[0].fsx_rox_id : ""
}

output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}

output "fsx_storage_fsx_rwx_dns_name" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_dns_name : ""
}

output "fsx_storage_fsx_rwx_mount_name" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_mount_name : ""
}

output "fsx_storage_fsx_rwx_volume_handle" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : ""
}

output "fsx_storage_fsx_rwx_subnet_id" {
  value = var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_subnet_ids[0] : ""
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

output "ns" {
  value = var.use_static_ssl_certificates ? ["no-hosted-zone"] : data.aws_route53_zone.primary[0].name_servers
}

data "external" "git_information" {
  program = ["sh", "${path.module}/get_sha.sh"]
}

output "git_sha" {
  value = data.external.git_information.result.sha
}

output "git_branch" {
  value = data.external.git_information.result.branch
}

output "minio-username" {
  value = "insights"
}

output "minio-password" {
  sensitive = true
  value     = var.insights_enabled ? random_password.minio-password[0].result : ""
}

output "nginx_ingress_security_group_id" {
  value = var.create_nginx_ingress_security_group &&var.network_module == "networking" && var.network_type == "create" ? local.network[0].nginx_ingress_security_group_id : ""
}

output "nat_gateway_eips" {
  value = var.network_module == "networking" && var.network_type == "create" ? local.network[0].nat_gateway_eips : [] 
}

output "nginx_ingress_allowed_cidrs" {
  value = var.nginx_ingress_allowed_cidrs
}
