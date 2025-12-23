

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
  triggers = {
    always_run = "${timestamp()}"
  }
  #download vault binary
  provisioner "local-exec" {
    command = "curl -L -o vault.zip https://releases.hashicorp.com/vault/1.19.5/vault_1.19.5_linux_amd64.zip"
  }
  #unzip vault binary
  provisioner "local-exec" {
    command = "unzip vault.zip"
  }

  provisioner "local-exec" {
    command = "chmod +x vault"
  }
}

resource "null_resource" "vault_auth_backend" {
  depends_on = [kubernetes_secret_v1.vault-auth-default, null_resource.download_vault]
  provisioner "local-exec" {
    command = "./vault login -method=userpass -address=${var.vault_address} username=${var.vault_username} password=$VAULT_PASSWORD"
    environment = {
      VAULT_PASSWORD = "${var.vault_password}"
    }
    quiet = true
  }
  provisioner "local-exec" {
    command = "./vault auth enable -path=${local.account_region_name} kubernetes || true"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
  provisioner "local-exec" {
    command = "./vault write auth/${local.account_region_name}/config kubernetes_host=${var.kubernetes_host} token_reviewer_jwt='${kubernetes_secret_v1.vault-auth-default.data["token"]}' kubernetes_ca_cert='${local.kube_ca_cert}' disable_local_ca_jwt=true disable_iss_validation=true"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
  provisioner "local-exec" {
    command = "./vault policy write ${local.account_region_name} -<<EOT\n${local.vault_policies}\nEOT"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
  provisioner "local-exec" {
    command = "./vault write auth/${local.account_region_name}/role/vault-auth-role bound_service_account_names=${kubernetes_service_account_v1.vault-auth-default.metadata.0.name} bound_service_account_namespaces=indico token_policies=${local.account_region_name} token_ttl=3600 audience=${var.audience}"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
}

resource "null_resource" "lambda_sns_forwarder_auth_backend" {
  count      = var.lambda_sns_forwarder_enabled == true ? 1 : 0
  depends_on = [kubernetes_secret_v1.vault-auth-default, null_resource.download_vault, null_resource.vault_auth_backend]
  provisioner "local-exec" {
    command = "./vault auth enable -path=aws/${local.account_region_name} aws"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
  provisioner "local-exec" {
    command = "./vault write auth/aws/${local.account_region_name}/config/client secret_key=${var.aws_secret_key} access_key=${var.aws_access_key}"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
    quiet = true
  }

  provisioner "local-exec" {
    command = "./vault write auth/aws/${local.account_region_name}/role/vault-lambda-role auth_type=iam bound_iam_principal_arn=${var.lambda_sns_forwarder_iam_principal_arn} policies=${local.account_region_name} ttl=1h"
    environment = {
      VAULT_ADDR = "${var.vault_address}"
    }
  }
}


locals {
  vault_policies = <<EOT
path "indico-common/*" {
  capabilities = ["read", "list"]
}

path "customer-Indico-Devops/data/thanos-storage" {
  capabilities = ["read", "list"]
}
path "customer-${var.account}/*" {
  capabilities = ["read", "list", "create", "update", "patch", "delete"]
}

path "customer-${var.account}/environments/${var.environment}/*" {
  capabilities = ["read", "list", "create", "update", "patch", "delete"]
}
EOT

  kube_ca_cert = <<EOT
${kubernetes_secret_v1.vault-auth-default.data["ca.crt"]}
EOT
}

