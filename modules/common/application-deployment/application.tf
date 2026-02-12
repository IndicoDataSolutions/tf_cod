terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
    external = {
      source  = "hashicorp/external"
    }
  }
}

# Optionally load existing argocd-application YAML from GitHub to preserve HELM_VALUES
data "external" "fetch_argo_application" {
  program = ["python3", "${path.module}/scripts/fetch_github_file.py"]

  query = {
    repository = var.github_repo_name
    branch     = var.github_repo_branch
    path       = var.github_file_path
    token      = var.github_token
  }
}

locals {
  existing_exists = data.external.fetch_argo_application.result.exists == "true"
  existing_yaml = local.existing_exists ? (
    try(yamldecode(base64decode(data.external.fetch_argo_application.result.content_base64)), {})
  ) : {}
  env_list = try(local.existing_yaml.spec.source.plugin.env, [])
  helm_values_from_file = try(
    [for e in local.env_list : e.value if e.name == "HELM_VALUES"][0],
    ""
  )
  helm_values_to_use = local.existing_exists && local.helm_values_from_file != "" ? local.helm_values_from_file : var.helm_values
}

resource "github_repository_file" "argocd-application-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = var.github_repo_name
  branch              = var.github_repo_branch
  file                = var.github_file_path
  commit_message      = var.github_commit_message
  overwrite_on_create = true
  depends_on = [
    data.external.fetch_argo_application
  ]

  # lifecycle {
  #   ignore_changes = [
  #     content
  #   ]
  # }

  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${var.argo_application_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: ${var.argo_vault_plugin_path}
    argocd.argoproj.io/sync-wave: "-2"
spec:
  ignoreDifferences:
    - group: apps
      jsonPointers:
        - /spec/replicas
      kind: Deployment
    - group: apps
      kind: Deployment
      jqPathExpressions:
      - .spec.template.spec.containers[].env[] | select((.name | contains("STAKATER_")))
    - group: ""
      kind: Secret
      name: runtime-scanner-auth
      jqPathExpressions:
      - '.data.auth'
  destination:
    server: ${var.argo_server}
    namespace: ${var.namespace}
  project: ${var.argo_project_name}
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
  source:
    chart: ${var.chart_name}
    repoURL: ${replace(var.chart_repo, "oci://", "")}
    targetRevision: ${var.chart_version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"

        - name: RELEASE_NAME
          value: ${var.release_name}
        
        - name: HELM_TF_COD_VALUES
          value: |
            ${var.terraform_helm_values}
        - name: HELM_VALUES
          value: |
            ${local.helm_values_to_use}
EOT
}
