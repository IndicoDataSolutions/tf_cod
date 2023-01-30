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


#  Now, we get back the output of the script
output "openshift_api_server_ip" {
  value = "none"
}

output "openshift_console_ip" {
  value = "none"
}


#  Now, we get back the output of the script
output "kubernetes_host" {
  value = trimspace(data.local_file.kubernetes_host.content)
}

output "kubernetes_client_certificate" {
  value = data.local_file.kubernetes_client_certificate.content
}

output "kubernetes_client_key" {
  value = data.local_file.kubernetes_client_key.content
}

output "kubernetes_cluster_ca_certificate" {
  value = base64decode(data.local_file.kubernetes_cluster_ca_certificate.content)
}

output "kube_config_file" {
  value = data.local_file.kube_config_file.content
}


