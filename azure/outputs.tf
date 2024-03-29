output "workload_identity_client_id" {
  value = var.use_workload_identity == true ? azuread_application.workload_identity.0.application_id : ""
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

output "harness_delegate_name" {
  value = var.harness_delegate == true && length(module.harness_delegate) > 0 ? module.harness_delegate[0].delegate_name : ""
}

# use this so Thanatos knows what resource group name to use for a destroy
output "resource_group_name" {
  value = local.resource_group_name
}

output "cluster_manager_ip" {
  value = var.private_cluster_enabled == true ? module.cluster-manager[0].cluster_manager_ip : ""
}

