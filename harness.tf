module "harness_delegate" {
  count = var.harness_delegate && strcontains(lower(var.aws_account), "indico") ? 1 : 0

  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]

  source = "./modules/harness"

  account_id       = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_ACCOUNT_ID"]
  delegate_token   = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_TOKEN"]
  delegate_name    = "${var.cluster_name}-harness-delegate"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image   = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_IMAGE"]
  replicas         = var.harness_delegate_replicas
  upgrader_enabled = true

  # Additional optional values to pass to the helm chart
  values = yamlencode({
    javaOpts : "-Xms64M"
  })
}

data "vault_kv_secret_v2" "delegate_secrets" {
  count = var.harness_delegate && strcontains(lower(var.aws_account), "indico") ? 1 : 0
  mount = var.harness_mount_path
  name  = "delegate"
}

