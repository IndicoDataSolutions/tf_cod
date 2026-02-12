# Pass-through debug outputs from application-deployment (intake_application) for HELM_VALUES debugging
output "argo_debug_fetch_exists" {
  description = "Whether argocd-application file was found in GitHub"
  value       = module.intake_application.argo_debug_fetch_exists
}

output "argo_debug_content_base64_length" {
  description = "Base64 content length from GitHub"
  value       = module.intake_application.argo_debug_content_base64_length
}

output "argo_debug_yaml_top_level_keys" {
  description = "Top-level keys in decoded YAML"
  value       = module.intake_application.argo_debug_yaml_top_level_keys
}

output "argo_debug_has_spec_source_plugin" {
  description = "Has spec.source.plugin"
  value       = module.intake_application.argo_debug_has_spec_source_plugin
}

output "argo_debug_env_list_length" {
  description = "Number of env entries"
  value       = module.intake_application.argo_debug_env_list_length
}

output "argo_debug_env_names" {
  description = "Env entry names (should include HELM_VALUES)"
  value       = module.intake_application.argo_debug_env_names
}

output "argo_debug_helm_values_from_file_length" {
  description = "Length of extracted HELM_VALUES from file"
  value       = module.intake_application.argo_debug_helm_values_from_file_length
}

output "argo_debug_helm_values_source" {
  description = "Which source is used for HELM_VALUES (file or var)"
  value       = module.intake_application.argo_debug_helm_values_source
}
