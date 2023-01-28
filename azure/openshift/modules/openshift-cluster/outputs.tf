# Stubbed outputs (not used)
output "kubelet_identity" {
  value = {
    object_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
    client_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
  }
}

output "oidc_issuer_url" {
  value = "ERROR:OPENSHIFT-NOT-APPLICABLE"
}

output "id" {
  value = "ERROR:OPENSHIFT-NOT-APPLICABLE"
}

output "kubernetes_host" {
  value = trimspace(data.local_file.api_ip.content)
}

output "kubernetes_insecure" {
  value = true
}

output "kubernetes_url" {
  value = "https://${trimspace(data.local_file.api_ip.content)}:6443"
}

#  Now, we get back the output of the script
output "kubernetes_username" {
  value = trimspace(data.local_file.username.content)
}

output "kubernetes_password" {
  value = trimspace(data.local_file.password.content)
}

output "api_server_ip" {
  value = trimspace(data.local_file.api_ip.content)
}

output "console_ingress_ip" {
  value = trimspace(data.local_file.console_url.content)
}


