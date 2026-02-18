data "terraform_remote_state" "environment" {
  count   = var.load_environment == "" ? 0 : 1
  backend = "remote"
  config = {
    organization = "indico"
    workspaces = {
      name = var.load_environment
    }
  }
}

locals {
  environment_indico_vpc_id                          = var.load_environment == "" ? module.networking[0].indico_vpc_id : data.terraform_remote_state.environment[0].outputs.indico_vpc_id
  environment_private_subnet_ids                     = var.load_environment == "" ? module.networking[0].private_subnet_ids : data.terraform_remote_state.environment[0].outputs.private_subnet_ids
  environment_public_subnet_ids                      = var.load_environment == "" ? module.networking[0].public_subnet_ids : data.terraform_remote_state.environment[0].outputs.public_subnet_ids
  environment_all_subnets_sg_id                      = var.load_environment == "" ? module.networking[0].all_subnets_sg_id : data.terraform_remote_state.environment[0].outputs.all_subnets_sg_id
  environment_indico_ipa_topic_arn                   = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_ipa_topic_arn : "null" : data.terraform_remote_state.environment[0].outputs.indico_ipa_topic_arn
  environment_indico_ipa_queue_arn                   = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_ipa_queue_arn : "null" : data.terraform_remote_state.environment[0].outputs.indico_ipa_queue_arn
  environment_indico_sqs_sns_policy_name             = var.load_environment == "" ? var.sqs_sns == true ? module.sqs_sns[0].indico_sqs_sns_policy_name : "null" : data.terraform_remote_state.environment[0].outputs.indico_sqs_sns_policy_name
  environment_kms_key_arn                            = var.load_environment == "" ? module.kms_key[0].key_arn : data.terraform_remote_state.environment[0].outputs.kms_key_arn
  environment_kms_key_key                            = var.load_environment == "" ? module.kms_key[0].key : data.terraform_remote_state.environment[0].outputs.kms_key_key
  environment_kms_key_key_id                         = var.load_environment == "" ? module.kms_key[0].key.id : data.terraform_remote_state.environment[0].outputs.kms_key_key_id
  environment_api_models_s3_bucket_name              = var.load_environment == "" ? coalesce(module.s3-storage[0].api_models_s3_bucket_name, "null") : data.terraform_remote_state.environment[0].outputs.api_models_s3_bucket_name
  environment_data_s3_bucket_name                    = var.load_environment == "" ? coalesce(module.s3-storage[0].data_s3_bucket_name, "null") : data.terraform_remote_state.environment[0].outputs.data_s3_bucket_name
  environment_pgbackup_s3_bucket_name                = var.load_environment == "" ? coalesce(module.s3-storage[0].pgbackup_s3_bucket_name, "null") : data.terraform_remote_state.environment[0].outputs.pgbackup_s3_bucket_name
  environment_miniobkp_s3_bucket_name                = var.load_environment == "" ? coalesce(module.s3-storage[0].miniobkp_s3_bucket_name, "null") : data.terraform_remote_state.environment[0].outputs.miniobkp_s3_bucket_name
  environment_loki_s3_bucket_name                    = var.load_environment == "" ? coalesce(module.s3-storage[0].loki_s3_bucket_name, "null") : data.terraform_remote_state.environment[0].outputs.loki_s3_bucket_name
  environment_efs_filesystem_id                      = var.load_environment == "" ? var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : "null" : data.terraform_remote_state.environment[0].outputs.efs_filesystem_id
  environment_fsx_rwx_id                             = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : "null" : data.terraform_remote_state.environment[0].outputs.fsx_rwx_id
  environment_fsx_rwx_arn                            = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_arn : "null" : data.terraform_remote_state.environment[0].outputs.fsx_rwx_arn
  environment_fsx_rwx_subnet_ids                     = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_subnet_ids : ["null"] : data.terraform_remote_state.environment[0].outputs.fsx_rwx_subnet_ids
  environment_fsx_rwx_subnet_id                      = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_subnet_ids[0] : "null" : data.terraform_remote_state.environment[0].outputs.fsx_storage_fsx_rwx_subnet_id
  environment_fsx_rwx_security_group_ids             = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_security_group_ids : ["null"] : data.terraform_remote_state.environment[0].outputs.fsx_rwx_security_group_ids
  environment_fsx_rwx_mount_name                     = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_mount_name : "null" : data.terraform_remote_state.environment[0].outputs.fsx_storage_fsx_rwx_mount_name
  environment_fsx_rwx_volume_handle                  = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_id : "null" : data.terraform_remote_state.environment[0].outputs.fsx_storage_fsx_rwx_volume_handle
  environment_fsx_rwx_dns_name                       = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rwx_dns_name : "null" : data.terraform_remote_state.environment[0].outputs.fsx_storage_fsx_rwx_dns_name
  environment_fsx_rox_id                             = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rox_id : "null" : data.terraform_remote_state.environment[0].outputs.fsx_rox_id
  environment_fsx_rox_arn                            = var.load_environment == "" ? var.include_fsx == true ? module.fsx-storage[0].fsx_rox_arn : "null" : data.terraform_remote_state.environment[0].outputs.fsx_rox_arn
  environment_cluster_role_name                      = var.load_environment == "" ? coalesce(module.iam[0].cluster_role_name, "null") : data.terraform_remote_state.environment[0].outputs.cluster_role_name
  environment_cluster_role_arn                       = var.load_environment == "" ? var.create_eks_cluster_role ? (var.eks_cluster_iam_role_name_override == null ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-cluster-${var.label}-${var.region}" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_cluster_iam_role_name_override}") : "null" : data.terraform_remote_state.environment[0].outputs.cluster_role_arn
  environment_node_role_name                         = var.load_environment == "" ? coalesce(module.iam[0].node_role_name, "null") : data.terraform_remote_state.environment[0].outputs.node_role_name
  environment_node_role_arn                          = var.load_environment == "" ? coalesce(module.iam[0].node_role_arn, "null") : data.terraform_remote_state.environment[0].outputs.node_role_arn
  environment_s3_backup_role_name                    = var.load_environment == "" ? coalesce(module.iam[0].s3_backup_role_name, "null") : data.terraform_remote_state.environment[0].outputs.s3_backup_role_name
  environment_s3_backup_role_arn                     = var.load_environment == "" ? coalesce(module.iam[0].s3_backup_role_arn, "null") : data.terraform_remote_state.environment[0].outputs.s3_backup_role_arn
  environment_s3_replication_role_name               = var.load_environment == "" ? coalesce(module.iam[0].s3_replication_role_name, "null") : data.terraform_remote_state.environment[0].outputs.s3_replication_role_name
  environment_s3_replication_role_arn                = var.load_environment == "" ? coalesce(module.iam[0].s3_replication_role_arn, "null") : data.terraform_remote_state.environment[0].outputs.s3_replication_role_arn
  environment_vpc_flow_logs_role_name                = var.load_environment == "" ? coalesce(module.iam[0].vpc_flow_logs_role_name, "null") : data.terraform_remote_state.environment[0].outputs.vpc_flow_logs_role_name
  environment_vpc_flow_logs_role_arn                 = var.load_environment == "" ? coalesce(module.iam[0].vpc_flow_logs_role_arn, "null") : data.terraform_remote_state.environment[0].outputs.vpc_flow_logs_role_arn
  environment_nginx_ingress_security_group_id        = var.load_environment == "" ? (var.create_nginx_ingress_security_group && var.network_type == "create" ? module.networking[0].nginx_ingress_security_group_id : "null") : data.terraform_remote_state.environment[0].outputs.nginx_ingress_security_group_id
  environment_nat_gateway_eips                       = var.load_environment == "" ? (var.network_type == "create" ? module.networking[0].nat_gateway_eips : ["null"]) : data.terraform_remote_state.environment[0].outputs.nat_gateway_eips
  environment_nginx_ingress_allowed_cidrs            = var.load_environment == "" ? (var.nginx_ingress_allowed_cidrs) : data.terraform_remote_state.environment[0].outputs.nginx_ingress_allowed_cidrs
  environment_lambda_sns_forwarder_iam_principal_arn = var.load_environment == "" ? var.lambda_sns_forwarder_enabled == true ? module.lambda-sns-forwarder[0].lambda_sns_forwarder_iam_principal_arn : "null" : data.terraform_remote_state.environment[0].outputs.lambda_sns_forwarder_iam_principal_arn

  # Cluster module outputs - AWS
  environment_cluster_kubernetes_host                   = var.load_environment == "" ? module.cluster[0].kubernetes_host : data.terraform_remote_state.environment[0].outputs.kube_host
  environment_cluster_kubernetes_cluster_ca_certificate = var.load_environment == "" ? module.cluster[0].kubernetes_cluster_ca_certificate : data.terraform_remote_state.environment[0].outputs.kube_ca_certificate
  environment_cluster_kubernetes_token                  = var.load_environment == "" ? module.cluster[0].kubernetes_token : data.terraform_remote_state.environment[0].outputs.kube_token
  environment_cluster_node_security_group_id            = var.load_environment == "" ? module.cluster[0].node_security_group_id : data.terraform_remote_state.environment[0].outputs.cluster_node_security_group_id
  environment_cluster_cluster_security_group_id         = var.load_environment == "" ? module.cluster[0].cluster_security_group_id : data.terraform_remote_state.environment[0].outputs.cluster_security_group_id
  environment_cluster_cluster_name                      = var.load_environment == "" ? module.cluster[0].cluster_name : data.terraform_remote_state.environment[0].outputs.cluster_name
  environment_cluster_cluster_endpoint                  = var.load_environment == "" ? module.cluster[0].cluster_endpoint : data.terraform_remote_state.environment[0].outputs.cluster_endpoint
  environment_cluster_node_groups                       = var.load_environment == "" ? module.cluster[0].node_groups : data.terraform_remote_state.environment[0].outputs.cluster_node_groups
  environment_argo_project_name                         = var.load_environment == "" ? var.argo_enabled == true ? module.argo-registration[0].argo_project_name : "null" : data.terraform_remote_state.environment[0].outputs.argo_project_name
}
