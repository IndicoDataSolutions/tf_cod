module "delegate" {
  count = var.harness_delegate == true ? 1 : 0

  source = "harness/harness-delegate/kubernetes"
  version = "0.1.6"

  account_id       = jsondecode(data.vault_kv_secret_v2.delegate_secrets.data_json)["DELEGATE_ACCOUNT_ID"]
  delegate_token   = jsondecode(data.vault_kv_secret_v2.delegate_secrets.data_json)["DELEGATE_TOKEN"]
  delegate_name    = var.cluster_name + "-harness-delegate"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io/gratis"
  delegate_image   = jsondecode(data.vault_kv_secret_v2.delegate_secrets.data_json)["DELEGATE_IMAGE"]
  replicas         = 1
  upgrader_enabled = false

  # Additional optional values to pass to the helm chart
  values = yamlencode({
    javaOpts: "-Xms64M"
  })
}

data "vault_kv_secret_v2" "delegate_secrets" {
  mount = var.harness_mount_path
  name  = "delegate"
}