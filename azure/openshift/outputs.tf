output "triggers" {
  sensitive = true
  value     = module.infrastructure.0.triggers
}
