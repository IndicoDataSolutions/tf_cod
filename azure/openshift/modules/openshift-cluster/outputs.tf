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
  depends_on = [
    data.local_file.kubeconfig
  ]
  value = yamldecode(data.local_file.kubeconfig.content)["users"][0]["user"]["token"]
}

output "kubernetes_host" {
  value = jsondecode(module.shell-kube-host.stdout)["apiUrl"]
}

#  Now, we get back the output of the script
output "kubernetes_username" {
  value = jsondecode(module.shell-kube-credentials.stdout)["kubeadminUsername"]
}

output "kubernetes_password" {
  value = jsondecode(module.shell-kube-credentials.stdout)["kubeadminPassword"]
}

