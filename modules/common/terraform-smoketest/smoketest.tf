data "vault_kv_secret_v2" "harbor-api-token" {
  count = var.argo_enabled == true ? 1 : 0
  mount = "tools/argo"
  name  = "harbor-api"
}

resource "null_resource" "wait-for-tf-cod-chart-build" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      HARBOR_API_TOKEN = jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"]
    }
    command = "${path.module}/validate_chart.sh terraform-smoketests 0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
  }
}

data "external" "git_information" {
  program = ["sh", "${path.module}/get_sha.sh"]
}

resource "helm_release" "terraform-smoketests" {

  depends_on = [
    null_resource.wait-for-tf-cod-chart-build,
    #null_resource.sleep-5-minutes-wait-for-charts-smoketest-build,
    kubernetes_config_map.terraform-variables,
    helm_release.monitoring
  ]

  verify           = false
  name             = "terraform-smoketests-${substr(data.external.git_information.result.sha, 0, 8)}"
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "terraform-smoketests"
  version          = "0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
  wait             = true
  wait_for_jobs    = true
  timeout          = "300" # 5 minutes
  disable_webhooks = false
  values = [<<EOF
  cluster:
    cloudProvider: aws
    account: ${var.aws_account}
    region: ${var.region}
    name: ${var.label}
  image:
    tag: "${substr(data.external.git_information.result.sha, 0, 8)}"
  EOF
  ]
}
