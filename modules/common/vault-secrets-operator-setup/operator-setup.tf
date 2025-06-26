

resource "kubernetes_service_account_v1" "vault-auth-default" {
  metadata {
    name      = "vault-auth"
    namespace = "indico"
  }

  automount_service_account_token = true

  image_pull_secret {
    name = "harbor-pull-secret"
  }
}

# The CRB is needed so vault can auth back to this cluster, see:
resource "kubernetes_cluster_role_binding" "vault-auth" {
  metadata {
    name = "role-tokenreview-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.vault-auth-default.metadata.0.name
    namespace = kubernetes_service_account_v1.vault-auth-default.metadata.0.namespace
  }
}

resource "kubernetes_secret_v1" "vault-auth-default" {
  depends_on = [kubernetes_service_account_v1.vault-auth-default]
  metadata {
    name      = "vault-auth"
    namespace = "indico"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.vault-auth-default.metadata.0.name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "null_resource" "download_vault" {
  #download vault binary
  provisioner "local-exec" {
    command = "curl -L -o vault.zip https://releases.hashicorp.com/vault/1.19.5/vault_1.19.5_linux_amd64.zip"
  }
  #unzip vault binary
  provisioner "local-exec" {
    command = "unzip vault.zip"
  }
}

resource "null_resource" "vault_auth_backend" {
  depends_on = [kubernetes_secret_v1.vault-auth-default, null_resource.download_vault]
  provisioner "local-exec" {
    command = "./vault login -method=userpass -address=${var.vault_address} username=${var.vault_username} password='${var.vault_password}'"
    quiet = true
  }
  provisioner "local-exec" {
    command = "./vault auth enable kubernetes -path=${local.account_region_name}"
  }
  provisioner "local-exec" {
    command = "./vault write auth/${local.account_region_name}/config kubernetes_host=${var.kubernetes_host} token_reviewer_jwt=${kubernetes_secret_v1.vault-auth-default.data["token"]} kubernetes_ca_cert=${kubernetes_secret_v1.vault-auth-default.data["ca.crt"]} disable_local_ca_jwt=true disable_iss_validation=true"
  }
  provisioner "local-exec" {
    command = "./vault policy write ${local.account_region_name} -<<EOT\n${local.vault_policies}\nEOT"
  }
  provisioner "local-exec" {
    command = "./vault write auth/${local.account_region_name}/role/vault-auth-role bound_service_account_names=${kubernetes_service_account_v1.vault-auth-default.metadata.0.name} bound_service_account_namespaces=indico token_policies=${local.account_region_name} token_ttl=3600"
  }
}

# resource "vault_auth_backend" "kubernetes" {
#   type = "kubernetes"
#   path = local.account_region_name
# }

# vault read auth/indico-dev-us-east-2-dop-999/config
# resource "vault_kubernetes_auth_backend_config" "vault-auth" {
#   disable_iss_validation = true
#   disable_local_ca_jwt   = true
#   backend                = vault_auth_backend.kubernetes.path
#   kubernetes_host        = var.kubernetes_host
#   token_reviewer_jwt     = kubernetes_secret_v1.vault-auth-default.data["token"]
#   kubernetes_ca_cert     = kubernetes_secret_v1.vault-auth-default.data["ca.crt"]
# }

# resource "vault_policy" "vault-auth-policy" {
#   name = local.account_region_name

#   policy = <<EOT
# path "indico-common/*" {
#   capabilities = ["read", "list"]
# }

# path "customer-Indico-Devops/data/thanos-storage" {
#   capabilities = ["read", "list"]
# }
# path "customer-${var.account}/*" {
#   capabilities = ["read", "list"]
# }
# EOT
# }

locals {
  vault_policies = <<EOT
path "indico-common/*" {
  capabilities = ["read", "list"]
}

path "customer-Indico-Devops/data/thanos-storage" {
  capabilities = ["read", "list"]
}
path "customer-${var.account}/*" {
  capabilities = ["read", "list"]
}
EOT
}

# resource "vault_kubernetes_auth_backend_role" "vault-auth-role" {
#   backend                          = vault_auth_backend.kubernetes.path
#   role_name                        = "vault-auth-role"
#   bound_service_account_names      = [kubernetes_service_account_v1.vault-auth-default.metadata.0.name]
#   bound_service_account_namespaces = ["indico"]
#   token_ttl                        = 3600
#   token_policies                   = [vault_policy.vault-auth-policy.name]
#   audience                         = var.audience
# }
