output "monitoring_password" {
  value = random_password.monitoring-password.result
}

output "monitoring_username" {
  value = "monitoring"
}