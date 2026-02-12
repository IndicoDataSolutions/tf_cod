output "key_pem" {
  value       = var.multitenant_enabled == false ? tls_private_key.pk[0].private_key_pem : ""
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

output "argo_project_name" {
  value = local.environment_argo_project_name
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

output "lambda_sns_forwarder_iam_principal_arn" {
  value = local.environment_lambda_sns_forwarder_iam_principal_arn
}

## Argo HELM_VALUES debug outputs (application-deployment module)
# IPA: intake module re-exports application-deployment outputs; try() when IPA disabled

# IPA (intake) application
output "argo_debug_ipa_fetch_exists" {
  description = "[Debug] IPA: whether argocd-application file was found in GitHub"
  value       = try(module.intake[0].argo_debug_fetch_exists, null)
}

output "argo_debug_ipa_content_base64_length" {
  description = "[Debug] IPA: base64 content length from GitHub"
  value       = try(module.intake[0].argo_debug_content_base64_length, null)
}

output "argo_debug_ipa_yaml_top_level_keys" {
  description = "[Debug] IPA: top-level keys in decoded YAML"
  value       = try(module.intake[0].argo_debug_yaml_top_level_keys, null)
}

output "argo_debug_ipa_has_spec_source_plugin" {
  description = "[Debug] IPA: has spec.source.plugin"
  value       = try(module.intake[0].argo_debug_has_spec_source_plugin, null)
}

output "argo_debug_ipa_env_list_length" {
  description = "[Debug] IPA: number of env entries"
  value       = try(module.intake[0].argo_debug_env_list_length, null)
}

output "argo_debug_ipa_env_names" {
  description = "[Debug] IPA: env entry names (should include HELM_VALUES)"
  value       = try(module.intake[0].argo_debug_env_names, null)
}

output "argo_debug_ipa_helm_values_from_file_length" {
  description = "[Debug] IPA: length of extracted HELM_VALUES from file"
  value       = try(module.intake[0].argo_debug_helm_values_from_file_length, null)
}

output "argo_debug_ipa_helm_values_source" {
  description = "[Debug] IPA: which source is used for HELM_VALUES (file or var)"
  value       = try(module.intake[0].argo_debug_helm_values_source, null)
}

# Smoketests application (when enabled)
output "argo_debug_smoketests_fetch_exists" {
  description = "[Debug] Smoketests: whether argocd-application file was found"
  value       = length(try(module.intake_smoketests, [])) > 0 ? module.intake_smoketests[0].argo_debug_fetch_exists : null
}

output "argo_debug_smoketests_env_names" {
  description = "[Debug] Smoketests: env entry names"
  value       = length(try(module.intake_smoketests, [])) > 0 ? module.intake_smoketests[0].argo_debug_env_names : null
}

output "argo_debug_smoketests_helm_values_source" {
  description = "[Debug] Smoketests: HELM_VALUES source (file or var)"
  value       = length(try(module.intake_smoketests, [])) > 0 ? module.intake_smoketests[0].argo_debug_helm_values_source : null
}

# Additional applications (for_each)
output "argo_debug_additional_fetch_exists" {
  description = "[Debug] Additional apps: whether file was found, by app key"
  value       = { for k, v in try(module.additional_application, {}) : k => v.argo_debug_fetch_exists }
}

output "argo_debug_additional_env_names" {
  description = "[Debug] Additional apps: env names, by app key"
  value       = { for k, v in try(module.additional_application, {}) : k => v.argo_debug_env_names }
}

output "argo_debug_additional_helm_values_source" {
  description = "[Debug] Additional apps: HELM_VALUES source (file or var), by app key"
  value       = { for k, v in try(module.additional_application, {}) : k => v.argo_debug_helm_values_source }
}
