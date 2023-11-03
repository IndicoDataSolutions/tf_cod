


resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = local.account_region_name
}


/*
resource "vault_kubernetes_auth_backend_config" "cluster-auth" {
  kubernetes_host        = "https://${var.k8s_svc_host_ip}:443"
  disable_iss_validation = "true"
  #  issuer="https://kubernetes.default.svc.cluster.local"
  token_reviewer_jwt = data.local_file.vault-token.content
  kubernetes_ca_cert = data.local_file.vault-ca.content
}
*/
