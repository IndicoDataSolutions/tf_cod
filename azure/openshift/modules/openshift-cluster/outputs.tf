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
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["kubernnetes_host"]
}

output "kubernetes_client_certificate" {
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["kubernetes_client_certificate"]
}

output "kubernetes_client_key" {
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["kubernetes_client_key"]
}

output "kubernetes_cluster_ca_certificate" {
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["kubernetes_cluster_ca_certificate"]
}

output "openshift_api_server_ip" {
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["api_ip"]
}

output "openshift_console_ip" {
  value = jsondecode(data.vault_kv_secret_v2.kubernetes-credentials.data_json)["console_ip"]
}



