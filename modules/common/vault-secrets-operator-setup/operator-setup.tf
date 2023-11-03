
resource "kubernetes_service_account_v1" "vault-auth" {
  metadata {
    name      = "vault-auth"
    namespace = "default"
  }

  automount_service_account_token = true

  image_pull_secret {
    name = "harbor-pull-secret"
  }
}

resource "kubernetes_secret_v1" "vault-auth" {
  metadata {
    name      = "vault-auth"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.vault-auth.metadata.0.name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = local.account_region_name
}


resource "vault_kubernetes_auth_backend_config" "vault-auth" {
  kubernetes_host        = var.kubernetes_host
  disable_iss_validation = "true"
  #  issuer="https://kubernetes.default.svc.cluster.local"
  token_reviewer_jwt = kubernetes_secret_v1.vault-auth.data["token"]
  kubernetes_ca_cert = kubernetes_secret_v1.vault-auth.data["ca.crt"]
}
