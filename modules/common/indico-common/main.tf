# Start with the crds and operators
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

resource "github_repository_file" "crds_values_yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = var.github_repo_name
  branch              = var.github_repo_branch
  file                = "${var.github_file_path}/helm/indico-crds-values.values"
  commit_message      = var.github_commit_message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.indico_crds_values_yaml_b64)
}

data "github_repository_file" "data_crds_values" {
  count = var.argo_enabled == true ? 1 : 0
  depends_on = [
    github_repository_file.crds_values_yaml
  ]
  repository = var.github_repo_name
  branch     = var.github_repo_branch
  file       = var.github_file_path == "." ? "helm/indico-crds-values.values" : "${var.github_file_path}/helm/indico-crds-values.values"
}

resource "helm_release" "indico_crds" {
  verify           = false
  name             = "indico-crds"
  create_namespace = true
  namespace        = var.namespace
  repository       = var.helm_registry
  chart            = "indico-crds"
  version          = var.indico_crds_version
  wait             = true
  timeout          = "1800" # 30 minutes
  max_history      = 10

  values = concat(var.indico_crds_values_overrides, [<<EOT
${var.argo_enabled == true ? data.github_repository_file.data_crds_values[0].content : base64decode(var.indico_crds_values_yaml_b64)}
EOT
  ])
}

# Wait for the crd chart to settle
resource "time_sleep" "wait_1_minutes_after_crds" {
  depends_on = [helm_release.indico_crds]

  create_duration = "1m"
}

# Operator installed, on to pre-reqs
resource "github_repository_file" "pre_reqs_values_yaml" {
  count               = var.argo_enabled == true ? 1 : 0
  repository          = var.github_repo_name
  branch              = var.github_repo_branch
  file                = "${var.github_file_path}/helm/indico-pre-reqs-values.values"
  commit_message      = var.github_commit_message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.indico_pre_reqs_values_yaml_b64)
}

data "github_repository_file" "data_pre_reqs_values" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    github_repository_file.pre_reqs_values_yaml
  ]
  repository = var.github_repo_name
  branch     = var.github_repo_branch
  file       = var.github_file_path == "." ? "helm/indico-pre-reqs-values.values" : "${var.github_file_path}/helm/indico-pre-reqs-values.values"
}

resource "helm_release" "indico_pre_requisites" {
  depends_on = [
    data.github_repository_file.data_pre_reqs_values,
    time_sleep.wait_1_minutes_after_crds,
  ]

  verify           = false
  name             = "indico-pre-reqs"
  create_namespace = true
  namespace        = var.namespace
  repository       = var.helm_registry
  chart            = "indico-pre-reqs"
  version          = var.indico_pre_reqs_version
  wait             = false
  timeout          = "1800" # 30 minutes
  disable_webhooks = false
  max_history      = 10

  values = concat(var.indico_pre_reqs_values_overrides, [<<EOT
${var.argo_enabled == true ? data.github_repository_file.data_pre_reqs_values[0].content : base64decode(var.indico_pre_reqs_values_yaml_b64)}
EOT
  ])
}

resource "helm_release" "monitoring" {
  depends_on = [helm_release.indico_pre_requisites]

  count = var.monitoring_enabled == true ? 1 : 0

  verify           = false
  name             = "monitoring"
  create_namespace = true
  namespace        = "monitoring"
  repository       = var.helm_registry
  chart            = "monitoring"
  version          = var.monitoring_version
  wait             = false
  timeout          = "1800" # 30 minutes
  max_history      = 10

  values = var.monitoring_values
}
