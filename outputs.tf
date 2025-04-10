output "key_pem" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated private key for key pair"
  sensitive   = true
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

## Environment outputs

## Network outputs
output "indico_vpc_id" {
  value = var.load_environment == "" ? local.network[0].vpc_id : local.environment_vpc_id
}

output "private_subnet_ids" {
  value = var.load_environment == "" ? local.network[0].private_subnet_ids : local.environment_private_subnet_ids
}

output "public_subnet_ids" {
  value = var.load_environment == "" ? local.network[0].public_subnet_ids : local.environment_public_subnet_ids
}

output "all_subnets_sg_id" {
  value = var.load_environment == "" ? var.network_module == "networking" ? local.network[0].all_subnets_sg_id : module.security-group.all_subnets_sg_id : local.environment_all_subnets_sg_id
}

## SQS outputs

output "indico_ipa_topic_arn" {
  value = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_ipa_topic_arn : "" : local.environment_indico_ipa_topic_arn
}

output "indico_ipa_queue_arn" {
  value = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_ipa_queue_arn : "" : local.environment_indico_ipa_queue_arn
}

output "indico_sqs_sns_policy_name" {
  value = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_sqs_sns_policy_name : "" : local.environment_indico_sqs_sns_policy_name
}

## KMS outputs

output "kms_key_arn" {
  value = var.load_environment == "" ? module.kms_key.key_arn : local.environment_kms_key_arn
}

output "kms_key" {
  value = var.load_environment == "" ? module.kms_key.key : local.environment_kms_key
}

## S3 outputs

output "api_models_s3_bucket_name" {
  description = "Name of the api-models s3 bucket"
  value       = var.load_environment == "" ? var.include_rox == true && var.api_models_s3_bucket_name_override == "" ? module.s3-storage[0].api_models_s3_bucket_name : var.api_models_s3_bucket_name_override : local.environment_api_models_s3_bucket_name
}

output "data_s3_bucket_name" {
  description = "Name of the data s3 bucket"
  value       = var.load_environment == "" ? var.data_s3_bucket_name_override == "" ? module.s3-storage[0].data_s3_bucket_name : var.data_s3_bucket_name_override : local.environment_data_s3_bucket_name
}

output "pgbackup_s3_bucket_name" {
  description = "Name of the pgbackup s3 bucket"
  value       = var.load_environment == "" ? var.pgbackup_s3_bucket_name_override == "" ? module.s3-storage[0].pgbackup_s3_bucket_name : var.pgbackup_s3_bucket_name_override : local.environment_pgbackup_s3_bucket_name
}

output "miniobkp_s3_bucket_name" {
  description = "Name of the miniobkp s3 bucket"
  value       = var.load_environment == "" ? var.miniobkp_s3_bucket_name_override == "" ? module.s3-storage[0].miniobkp_s3_bucket_name : var.miniobkp_s3_bucket_name_override : local.environment_miniobkp_s3_bucket_name
}

## EFS outputs

output "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  value       = var.load_environment == "" ? var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : "" : local.environment_efs_filesystem_id
}

## FSX outputs

output "fsx_rwx_id" {
  description = "Read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : "" : local.environment_fsx_rwx_id
}

output "fsx_storage_fsx_rwx_dns_name" {
  description = "DNS name of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_dns_name : "" : local.environment_fsx_storage_fsx_rwx_dns_name
}

output "fsx_rwx_arn" {
  description = "ARN of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_arn : "" : local.environment_fsx_rwx_arn
}

output "fsx_rwx_subnet_ids" {
  description = "Subnet IDs of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_subnet_ids : [] : local.environment_fsx_rwx_subnet_ids
}

output "fsx_storage_fsx_rwx_subnet_id" {
  description = "Subnet ID of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_subnet_ids[0] : "" : local.environment_fsx_rwx_subnet_ids[0]
}

output "fsx_rwx_security_group_ids" {
  description = "Security group IDs of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_security_group_ids : [] : local.environment_fsx_rwx_security_group_ids
}

output "fsx_storage_fsx_rwx_mount_name" {
  description = "Mount name of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_mount_name : "" : local.environment_fsx_rwx_mount_name
}

output "fsx_storage_fsx_rwx_volume_handle" {
  description = "Volume handle of the read write filesystem"
  value       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : "" : local.environment_fsx_storage_fsx_rwx_volume_handle
}

output "fsx_rox_id" {
  description = "ID of the read only filesystem"
  value       = var.load_environment == "" ? var.include_rox == true ? module.fsx-storage[0].fsx_rox_id : "" : local.environment_fsx_rox_id
}

## IAM outputs

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = var.load_environment == "" ? var.create_eks_cluster_role ? module.iam[0].cluster_role_name : "" : local.environment_cluster_role_name
}


output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = var.load_environment == "" ? var.create_eks_cluster_role ? module.iam[0].cluster_role_arn : "" : local.environment_cluster_role_arn
}

output "node_role_name" {
  description = "Name of the EKS node IAM role"
  value       = var.load_environment == "" ? var.create_eks_node_role ? module.iam[0].node_role_name : "" : local.environment_node_role_name
}

output "node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = var.load_environment == "" ? var.create_eks_node_role ? module.iam[0].node_role_arn : "" : local.environment_node_role_arn
}

output "s3_backup_role_name" {
  description = "Name of the S3 backup IAM role"
  value       = var.load_environment == "" ? var.enable_s3_backup ? module.iam[0].s3_backup_role_name : "" : local.environment_s3_backup_role_name
}

output "s3_backup_role_arn" {
  description = "ARN of the S3 backup IAM role"
  value       = var.load_environment == "" ? var.enable_s3_backup ? module.iam[0].s3_backup_role_arn : "" : local.environment_s3_backup_role_arn
}

output "s3_replication_role_name" {
  description = "Name of the S3 replication IAM role"
  value       = var.load_environment == "" ? var.enable_s3_replication ? module.iam[0].s3_replication_role_name : "" : local.environment_s3_replication_role_name
}

output "s3_replication_role_arn" {
  description = "ARN of the S3 replication IAM role"
  value       = var.load_environment == "" ? var.enable_s3_replication ? module.iam[0].s3_replication_role_arn : "" : local.environment_s3_replication_role_arn
}

output "vpc_flow_logs_role_name" {
  description = "Name of the VPC flow logs IAM role"
  value       = var.load_environment == "" ? var.enable_vpc_flow_logs ? module.iam[0].vpc_flow_logs_role_name : "" : local.environment_vpc_flow_logs_role_name
}

output "vpc_flow_logs_role_arn" {
  description = "ARN of the VPC flow logs IAM role"
  value       = var.load_environment == "" ? var.enable_vpc_flow_logs ? module.iam[0].vpc_flow_logs_role_arn : "" : local.environment_vpc_flow_logs_role_arn
}

output "minio-username" {
  value = "insights"
}

output "minio-password" {
  sensitive = true
  value     = var.insights_enabled ? random_password.minio-password[0].result : ""
}

output "nginx_ingress_security_group_id" {
  value = var.load_environment == "" ? var.create_nginx_ingress_security_group ? module.nginx-ingress[0].nginx_ingress_security_group_id : "" : local.environment_nginx_ingress_security_group_id
}

output "nat_gateway_eips" {
  value = var.load_environment == "" ? var.create_nginx_ingress_security_group ? module.nginx-ingress[0].nat_gateway_eips : [] : local.environment_nat_gateway_eips
}

output "nginx_ingress_allowed_cidrs" {
  value = var.load_environment == "" ? var.create_nginx_ingress_security_group ? module.nginx-ingress[0].nginx_ingress_allowed_cidrs : [] : local.environment_nginx_ingress_allowed_cidrs
}
