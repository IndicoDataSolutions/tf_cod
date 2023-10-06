data "github_repository" "argo-github-repo" {
  count     = var.argo_enabled == true ? 1 : 0
  full_name = "${var.github_organization}/${var.argo_repo}"
}

resource "github_repository_file" "smoketest-application-yaml" {
  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/apps/ipa_smoketest.yaml"
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
  name: ${local.argo_smoketest_app_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    server: ${var.kubernetes_host}
    namespace: ${var.ipa_namespace}
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
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
  
        - name: HELM_TF_COD_VALUES
          value: |
            prometheus:
              url: ${local.prometheus_address}

        - name: HELM_VALUES
          value: |
            ${indent(12, base64decode(var.ipa_smoketest_values))} 
            image:
              tag: ${var.ipa_smoketest_container_tag}
            cronjob:
              enabled: ${var.ipa_smoketest_cronjob_enabled}
              schedule: "${var.ipa_smoketest_cronjob_schedule}"
            cluster:
              name: ${var.label}
              region: ${var.region}
              account: ${var.account}
            host: ${local.dns_name}
            slack:
              channel: ${var.ipa_smoketest_slack_channel}
EOT
}
