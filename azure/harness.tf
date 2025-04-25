module "harness_delegate" {
  count = var.harness_delegate && strcontains(lower(var.account), "indico") ? 1 : 0

  depends_on = [
    module.cluster
  ]

  source = "../modules/harness"

  account_id       = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_ACCOUNT_ID"]
  delegate_token   = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_TOKEN"]
  delegate_name    = "${var.label}-harness-delegate"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io/gratis"
  delegate_image   = jsondecode(data.vault_kv_secret_v2.delegate_secrets[0].data_json)["DELEGATE_IMAGE"]
  upgrader_enabled = true

  # Additional optional values to pass to the helm chart
  values = yamlencode({
    javaOpts : "-Xms64M"
  })
}

data "vault_kv_secret_v2" "delegate_secrets" {
  count = var.harness_delegate && strcontains(lower(var.account), "indico") ? 1 : 0
  mount = var.harness_mount_path
  name  = "delegate"
}

