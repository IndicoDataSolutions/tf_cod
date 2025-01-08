# Start with application pre-reqs
resource "github_repository_file" "pre_reqs_values_yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = var.github_repo_name
  branch              = var.github_repo_branch
  file                = "${var.github_file_path}/helm/ins-pre-reqs-values.values"
  commit_message      = var.github_commit_message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.pre_reqs_values_yaml_b64)
}

data "github_repository_file" "data_pre_reqs_values" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    github_repository_file.pre_reqs_values_yaml
  ]
  repository = var.github_repo_name
  branch     = var.github_repo_branch
  file       = var.github_file_path == "." ? "helm/ins-pre-reqs-values.values" : "${var.github_file_path}/helm/ins-pre-reqs-values.values"
}

resource "helm_release" "ins_pre_requisites" {
  depends_on = [
    data.github_repository_file.data_pre_reqs_values,
  ]

  verify           = false
  name             = "insights-pre-reqs"
  create_namespace = true
  namespace        = var.namespace
  repository       = var.helm_registry
  chart            = "insights-pre-requisites"
  version          = var.ins_pre_reqs_version
  wait             = false
  timeout          = "1800" # 30 minutes
  disable_webhooks = false

  values = concat(var.ins_pre_reqs_values_overrides, [<<EOT
${var.argo_enabled == true ? data.github_repository_file.data_pre_reqs_values[0].content : base64decode(var.pre_reqs_values_yaml_b64)}
EOT
  ])
}

# Let pre-reqs settle
resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ins_pre_requisites]

  create_duration = "1m"
}

# Deploy the application
module "insights_application" {
  depends_on             = [time_sleep.wait_1_minutes_after_pre_reqs]
  source                 = "../application-deployment"
  account                = var.account
  region                 = var.region
  label                  = var.label
  namespace              = var.namespace
  argo_enabled           = var.argo_enabled
  github_repo_name       = var.github_repo_name
  github_repo_branch     = var.github_repo_branch
  github_file_path       = "${var.github_file_path}/ins_application.yaml"
  github_commit_message  = var.github_commit_message
  argo_application_name  = var.argo_application_name
  argo_vault_plugin_path = var.vault_path
  argo_server            = var.argo_server
  argo_project_name      = var.argo_project_name
  chart_name             = "insights"
  chart_repo             = var.helm_registry
  chart_version          = var.insights_version
  k8s_version            = var.k8s_version
  release_name           = "insights"
  terraform_helm_values  = var.insights_values_terraform_overrides
  helm_values            = var.insights_values_overrides
}
