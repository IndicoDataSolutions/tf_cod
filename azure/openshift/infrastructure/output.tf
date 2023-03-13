output "monitoring_password" {
  value = random_password.monitoring-password.result
}

output "monitoring_username" {
  value = "monitoring"
}

output "triggers" {
  value = module.openshift-infrastructure.0.triggers
}
