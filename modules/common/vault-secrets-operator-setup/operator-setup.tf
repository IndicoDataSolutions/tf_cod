
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
  disable_iss_validation = true
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  token_reviewer_jwt     = kubernetes_secret_v1.vault-auth.data["token"]
  kubernetes_ca_cert     = kubernetes_secret_v1.vault-auth.data["ca.crt"]
}

resource "vault_policy" "vault-auth-policy" {
  name = local.account_region_name

  policy = <<EOT

path "indico-common/*" {
  capabilities = ["read", "list"]
}

path "customer-${var.account}/*" {
  capabilities = ["read", "list"]
}
EOT
}


resource "vault_kubernetes_auth_backend_role" "vault-auth-role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-auth-role"
  bound_service_account_names      = [kubernetes_service_account_v1.vault-auth.metadata.0.name]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.vault-auth-policy.name]
  audience                         = var.audience
}
