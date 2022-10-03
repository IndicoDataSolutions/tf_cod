output "cluster_manager_ip" {
  value = module.cluster-manager.cluster_manager_ip
}

output "terraform_ip" {
  value = local.current_ip
}
