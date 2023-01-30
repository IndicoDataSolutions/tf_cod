
output "workload_identity_client_id" {
  value = azuread_application.workload_identity.application_id
}
