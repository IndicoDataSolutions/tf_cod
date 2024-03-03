
data "vault_kv_secret_v2" "zerossl_data" {
  mount = var.vault_mount_path
  name  = "zerossl"
}

# TODO: move to helm chart
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "harbor-pull-secret"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = "${base64decode(var.harbor_pull_secret_b64)}"
  }
}

resource "github_repository_file" "crds-values-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/infra-crds-values.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.crds-values-yaml-b64)
}

data "github_repository_file" "data-crds-values" {
  count = var.argo_enabled == true ? 1 : 0
  depends_on = [
    github_repository_file.crds-values-yaml
  ]
  repository = data.github_repository.argo-github-repo[0].name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/crds-values.values" : "${var.argo_path}/helm/infra-crds-values.values"
}

resource "helm_release" "ipa-crds" {
  depends_on = [
    module.cluster,
    data.github_repository_file.data-crds-values,
    module.secrets-operator-setup
  ]

  verify           = false
  name             = "infra-crds"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "infra-crds"
  version          = var.infra_crds_version
  wait             = true
  timeout          = "1800" # 30 minutes

  values = [
    <<EOF
  crunchy-pgo:
    enabled: true
    updateCRDs: 
      enabled: true

  
  cert-manager:
    nodeSelector:
      kubernetes.io/os: linux
    webhook:
      nodeSelector:
        kubernetes.io/os: linux
    cainjector:
      nodeSelector:
        kubernetes.io/os: linux
    enabled: true
    installCRDs: true
EOF
    ,
    <<EOT
${var.argo_enabled == true ? data.github_repository_file.data-crds-values[0].content : base64decode(var.crds-values-yaml-b64)}
EOT
  ]
}
