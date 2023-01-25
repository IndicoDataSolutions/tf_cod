# Stubbed outputs (not used)
output "kubelet_identity" {
  value = {
    object_id = "openshift-not-applicable"
    client_id = "openshift-not-applicable"
  }
}

output "oidc_issuer_url" {
  value = "openshift-not-applicable"
}

output "id" {
  value = "openshift-not-applicable"
}


# real outputs
output "kubernetes_token" {
  depends_on = [
    data.local_file.kubeconfig
  ]
  value = yamldecode(data.local_file.kubeconfig.content)["users"][0]["user"]["token"]
}

output "kubernetes_host" {
  value = jsondecode(module.shell-kube-credentials.stdout)["apiUrl"]
}

#  Now, we get back the output of the script
output "kubernetes_username" {
  value = jsondecode(module.shell-kube-credentials.stdout)["kubeadminUsername"]
}

output "kubernetes_password" {
  value = jsondecode(module.shell-kube-credentials.stdout)["kubeadminPassword"]
}

