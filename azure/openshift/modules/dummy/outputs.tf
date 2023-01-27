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


# real outputs
output "kubernetes_token" {
  value = ""
}

output "kubernetes_host" {
  value = ""
}

#  Now, we get back the output of the script
output "kubernetes_username" {
  value = ""
}

output "kubernetes_password" {
  value = ""
}

output "api_server_ip" {
  value = ""
}

output "console_ingress_ip" {

}


