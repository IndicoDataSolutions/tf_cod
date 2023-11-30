module "delegate" {
  count = var.harness_delegate == true ? 1 : 0

  source = "harness/harness-delegate/kubernetes"
  version = "0.1.5"

  account_id       = data.vault_generic_secret.harness_credentials.data["account_id"]
  delegate_token   = data.vault_generic_secret.harness_credentials.data["delegate_token"]
  delegate_name    = var.cluster_name + "-harness-delegate"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io/gratis"
#   delegate_image   = data.vault_generic_secret.harness_credentials.data["delegate_image"] -> To add to devops/ vault
  delegate_image   = "harness/delegate:23.11.81602" # Unsure if latest is supported
  replicas         = 1
  upgrader_enabled = false

  # Additional optional values to pass to the helm chart
  values = yamlencode({
    javaOpts: "-Xms64M"
  })
}

data "vault_generic_secret" "harness" {
  path = "path/to/harness/secrets" # ?
}