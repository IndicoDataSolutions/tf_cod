terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
  }
}

resource "github_repository_file" "argocd-application-yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = var.github_repo_name
  branch              = var.github_repo_branch
  file                = var.github_file_path
  commit_message      = var.github_commit_message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }

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
    repoURL: ${var.chart_repo}
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
            ${trimspace(var.terraform_helm_values)}
        - name: HELM_VALUES
          value: |
            ${trimspace(var.helm_values)}
EOT
}
