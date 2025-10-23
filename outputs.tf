output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
}

output "cluster_name" {
  value = local.environment_cluster_cluster_name
}

output "cluster_region" {
  value = var.region
}

output "dns_name" {
  value = local.dns_name
}

output "kube_host" {
  value = local.environment_cluster_kubernetes_host
}

output "kube_ca_certificate" {
  value = local.environment_cluster_kubernetes_cluster_ca_certificate

}
output "kube_token" {
  sensitive = true
  value     = local.environment_cluster_kubernetes_token
}

output "cluster_node_security_group_id" {
  value = local.environment_cluster_node_security_group_id
}

output "cluster_security_group_id" {
  value = local.environment_cluster_cluster_security_group_id
}

output "cluster_endpoint" {
  value = local.environment_cluster_cluster_endpoint
}

output "cluster_node_groups" {
  value = local.environment_cluster_node_groups
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

## Environment outputs

## Network outputs
output "indico_vpc_id" {
  value = local.environment_indico_vpc_id
}

output "private_subnet_ids" {
  value = local.environment_private_subnet_ids
}

output "public_subnet_ids" {
  value = local.environment_public_subnet_ids
}

output "all_subnets_sg_id" {
  value = local.environment_all_subnets_sg_id
}

## SQS outputs

output "indico_ipa_topic_arn" {
  value = local.environment_indico_ipa_topic_arn
}

output "indico_ipa_queue_arn" {
  value = local.environment_indico_ipa_queue_arn
}

output "indico_sqs_sns_policy_name" {
  value = local.environment_indico_sqs_sns_policy_name
}

## KMS outputs

output "kms_key_arn" {
  value = local.environment_kms_key_arn
}

output "kms_key_key" {
  value = local.environment_kms_key_key
}

output "kms_key_key_id" {
  value = local.environment_kms_key_key_id
}

## S3 outputs

output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = local.environment_api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = local.environment_data_s3_bucket_name
}

output "pgbackup_s3_bucket_name" {
  description = "Name of the pgbackup s3 bucket"
  value       = local.environment_pgbackup_s3_bucket_name
}

output "miniobkp_s3_bucket_name" {
  description = "Name of the miniobkp s3 bucket"
  value       = local.environment_miniobkp_s3_bucket_name
}

output "loki_s3_bucket_name" {
  description = "Name of the loki s3 bucket"
  value       = local.environment_loki_s3_bucket_name
}

## EFS outputs

output "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  value       = local.environment_efs_filesystem_id
}

## FSX outputs

output "fsx_rwx_id" {
  description = "Read write filesystem"
  value       = local.environment_fsx_rwx_id
}

output "fsx_storage_fsx_rwx_dns_name" {
  description = "DNS name of the read write filesystem"
  value       = local.environment_fsx_rwx_dns_name
}

output "fsx_rwx_arn" {
  description = "ARN of the read write filesystem"
  value       = local.environment_fsx_rwx_arn
}

output "fsx_rwx_subnet_ids" {
  description = "Subnet IDs of the read write filesystem"
  value       = local.environment_fsx_rwx_subnet_ids
}

output "fsx_storage_fsx_rwx_subnet_id" {
  description = "Subnet ID of the read write filesystem"
  value       = local.environment_fsx_rwx_subnet_id
}

output "fsx_rwx_security_group_ids" {
  description = "Security group IDs of the read write filesystem"
  value       = local.environment_fsx_rwx_security_group_ids
}

output "fsx_storage_fsx_rwx_mount_name" {
  description = "Mount name of the read write filesystem"
  value       = local.environment_fsx_rwx_mount_name
}

output "fsx_storage_fsx_rwx_volume_handle" {
  description = "Volume handle of the read write filesystem"
  value       = local.environment_fsx_rwx_volume_handle
}

output "fsx_rox_id" {
  description = "ID of the read only filesystem"
  value       = local.environment_fsx_rox_id
}

output "fsx_rox_arn" {
  description = "ARN of the read only filesystem"
  value       = local.environment_fsx_rox_arn
}

## IAM outputs

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = local.environment_cluster_role_name
}


output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = local.environment_cluster_role_arn
}

output "node_role_name" {
  description = "Name of the EKS node IAM role"
  value       = local.environment_node_role_name
}

output "node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = local.environment_node_role_arn
}

output "s3_backup_role_name" {
  description = "Name of the S3 backup IAM role"
  value       = local.environment_s3_backup_role_name
}

output "s3_backup_role_arn" {
  description = "ARN of the S3 backup IAM role"
  value       = local.environment_s3_backup_role_arn
}

output "s3_replication_role_name" {
  description = "Name of the S3 replication IAM role"
  value       = local.environment_s3_replication_role_name
}

output "s3_replication_role_arn" {
  description = "ARN of the S3 replication IAM role"
  value       = local.environment_s3_replication_role_arn
}

output "vpc_flow_logs_role_name" {
  description = "Name of the VPC flow logs IAM role"
  value       = local.environment_vpc_flow_logs_role_name
}

output "vpc_flow_logs_role_arn" {
  description = "ARN of the VPC flow logs IAM role"
  value       = local.environment_vpc_flow_logs_role_arn
}

output "minio-username" {
  value = "insights"
}

output "minio-password" {
  sensitive = true
  value     = var.insights_enabled ? random_password.minio-password[0].result : ""
}

output "nginx_ingress_security_group_id" {
  value = local.environment_nginx_ingress_security_group_id
}

output "nat_gateway_eips" {
  value = local.environment_nat_gateway_eips
}

output "nginx_ingress_allowed_cidrs" {
  value = local.environment_nginx_ingress_allowed_cidrs
}
