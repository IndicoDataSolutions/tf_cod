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

output "credentials" {
  value = trimspace(data.local_file.cluster_creds.content)
}

output "kubernetes_host" {
  value = trimspace(data.local_file.api_ip.content)
}

output "kubernetes_insecure" {
  value = false
}

output "kubernetes_url" {
  value = trimspace(data.local_file.api_url.content)
}

output "kubernetes_token" {
  value = trimspace(data.local_file.user_token.content)
}

output "kubernetes_sa_username" {
  value = trimspace(data.local_file.sa_username.content)
}

output "kubernetes_sa_token" {
  value = trimspace(data.local_file.sa_token.content)
}

output "kubernetes_sa_cert" {
  value = trimspace(data.local_file.sa_cert.content)
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


