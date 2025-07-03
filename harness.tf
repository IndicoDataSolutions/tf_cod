module "harness_delegate" {
  count = var.harness_delegate && strcontains(lower(var.aws_account), "indico") ? 1 : 0

  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    module.indico-common
  ]

  source = "./modules/harness"

  account_id       = var.harness_delegate_account_id
  delegate_token   = var.harness_delegate_token
  delegate_name    = "${var.cluster_name}-harness-delegate"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io/gratis"
  delegate_image   = var.harness_delegate_image
  upgrader_enabled = true

  # Additional optional values to pass to the helm chart
  values = yamlencode({
    javaOpts : "-Xms64M"
  })
}

