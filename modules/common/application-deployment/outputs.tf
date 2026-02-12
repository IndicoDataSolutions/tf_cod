# Debug outputs for HELM_VALUES extraction (remove or set sensitive = true in production)
# Run: terraform plan -out=tfplan && terraform show -json tfplan | jq '.planned_values.outputs'

output "argo_debug_fetch_exists" {
  description = "Whether the external script reported the file exists (string 'true' or 'false')"
  value       = local.debug_fetch_exists
}

output "argo_debug_content_base64_length" {
  description = "Length of base64 content returned; 0 means file not found or empty"
  value       = local.debug_content_base64_length
}

output "argo_debug_yaml_top_level_keys" {
  description = "Top-level keys in decoded YAML (expect: apiVersion, kind, metadata, spec)"
  value       = local.debug_yaml_keys
}

output "argo_debug_has_spec" {
  description = "Decoded YAML has spec key"
  value       = local.debug_has_spec
}

output "argo_debug_has_spec_source_plugin" {
  description = "Decoded YAML has spec.source.plugin"
  value       = local.debug_has_spec_source && local.debug_has_plugin
}

output "argo_debug_env_list_length" {
  description = "Number of entries in spec.source.plugin.env"
  value       = local.debug_env_list_length
}

output "argo_debug_env_names" {
  description = "Names of env entries (should include HELM_VALUES)"
  value       = local.debug_env_names
}

output "argo_debug_helm_values_from_file_length" {
  description = "Length of extracted HELM_VALUES string from file; 0 means not found or empty"
  value       = local.debug_helm_values_from_file_length
}

output "argo_debug_helm_values_source" {
  description = "Which source is used for HELM_VALUES: 'file' or 'var'"
  value       = local.debug_helm_values_source
}
