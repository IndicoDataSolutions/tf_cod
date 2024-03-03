locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}

resource "kubernetes_service_account_v1" "vault-auth-default" {
  metadata {
    name      = "vault-auth"
    namespace = "default"
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
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.vault-auth-default.metadata.0.name
    }
  }
  type = "kubernetes.io/service-account-token"
}


resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = local.account_region_name
}

# vault read auth/indico-dev-us-east-2-dop-999/config
resource "vault_kubernetes_auth_backend_config" "vault-auth" {
  disable_iss_validation = true
  disable_local_ca_jwt   = true
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  token_reviewer_jwt     = kubernetes_secret_v1.vault-auth-default.data["token"]
  kubernetes_ca_cert     = kubernetes_secret_v1.vault-auth-default.data["ca.crt"]
}

resource "vault_policy" "vault-auth-policy" {
  name = local.account_region_name

  policy = <<EOT
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

resource "vault_kubernetes_auth_backend_role" "vault-auth-role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-auth-role"
  bound_service_account_names      = [kubernetes_service_account_v1.vault-auth-default.metadata.0.name]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.vault-auth-policy.name]
  audience                         = var.audience
}

resource "helm_release" "ipa-vso" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]

  verify           = false
  name             = "ipa-vso"
  create_namespace = true
  namespace        = "default"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = "0.4.2"
  wait             = true
  values = [
    <<EOF
  controller: 
    imagePullSecrets:
      - name: harbor-pull-secret
    kubeRbacProxy:
      image:
        repository: harbor.devops.indico.io/gcr.io/kubebuilder/kube-rbac-proxy
      resources:
        limits:
          cpu: 500m
          memory: 1024Mi
        requests:
          cpu: 500m
          memory: 512Mi
    manager:
      image:
        repository: harbor.devops.indico.io/docker.io/hashicorp/vault-secrets-operator
      resources:
        limits:
          cpu: 500m
          memory: 1024Mi
        requests:
          cpu: 500m
          memory: 512Mi

  defaultAuthMethod:
    enabled: true
    namespace: default
    method: kubernetes
    mount: ${local.account_region_name}
    kubernetes:
      role: ${vault_kubernetes_auth_backend_role.vault-auth-role.role_name}
      tokenAudiences: ["vault"]
      serviceAccount: ${kubernetes_service_account_v1.vault-auth-default.metadata.0.name}

  defaultVaultConnection:
    enabled: true
    address: ${var.vault_address}
    skipTLSVerify: false
    spec:
    template:
      spec:
        containers:
        - name: manager
          args:
          - "--client-cache-persistence-model=direct-encrypted"
EOF
  ]
}


resource "helm_release" "external-secrets" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]


  verify           = false
  name             = "external-secrets"
  create_namespace = true
  namespace        = "default"
  repository       = "https://charts.external-secrets.io/"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  wait             = true

  values = [<<EOF
    image:
      repository: harbor.devops.indico.io/ghcr.io/external-secrets/external-secrets
    webhook:
     image:
        repository: harbor.devops.indico.io/ghcr.io/external-secrets/external-secrets
    certController:
      image:
        repository: harbor.devops.indico.io/ghcr.io/external-secrets/external-secrets

  EOF
  ]

}
