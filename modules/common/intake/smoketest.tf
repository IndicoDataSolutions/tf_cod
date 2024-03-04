
resource "github_repository_file" "smoketest-application-yaml" {
  count = var.ipa_smoketest_enabled == true && var.argo_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_smoketest.yaml"
  commit_message      = var.message
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
  name: ${lower("${var.aws_account}.${var.region}.${var.label}-smoketest")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.aws_account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: ${module.argo-registration[0].argo_project_name}
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true

  source:
    chart: cod-smoketests
    repoURL: ${var.ipa_smoketest_repo}
    targetRevision: ${var.ipa_smoketest_version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"

        - name: RELEASE_NAME
          value: run
      
        - name: HELM_VALUES
          value: |
            cluster:
              name: ${var.label}
              region: ${var.region}
              account: ${var.aws_account}
            host: ${var.dns_name}
            ${indent(12, base64decode(var.ipa_smoketest_values))}    
EOT
}
