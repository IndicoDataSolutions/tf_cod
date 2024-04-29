output "workload_identity_client_id" {
<<<<<<< HEAD
  value = azuread_application.workload_identity.application_id
=======
  value = var.use_workload_identity == true ? azuread_application.workload_identity.0.application_id : ""
}

output "cluster_name" {
  value = var.label
>>>>>>> 6edf13be4639e314fc3bb3529c63d6b853edd017
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

