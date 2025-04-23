resource "helm_release" "delegate" {
  name             = var.delegate_name
  repository       = var.helm_repository
  chart            = "harness-delegate-ng"
  version          = var.delegate_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [data.utils_deep_merge_yaml.values.output]
}

locals {
  values = yamlencode({
    accountId           = var.account_id,
    delegateToken       = var.delegate_token,
    managerEndpoint     = var.manager_endpoint,
    namespace           = var.namespace,
    delegateName        = var.delegate_name,
    delegateDockerImage = var.delegate_image,
    upgrader            = { enabled = var.upgrader_enabled }
    nextGen             = var.next_gen,
    proxyUser           = var.proxy_user,
    proxyPassword       = var.proxy_password,
    proxyHost           = var.proxy_host,
    proxyPort           = var.proxy_port,
    proxyScheme         = var.proxy_scheme,
    noProxy             = var.no_proxy,
    initScript          = var.init_script,
    deployMode          = var.deploy_mode,
    cpu                 = 2,
    memory              = 4096,
    autoscaling = {
      enabled                           = true,
      min                               = 1,
      max                               = 4,
      targetMemoryUtilizationPercentage = 80
    }
    delegateAnnotations = {
      "cluster-autoscaler.kubernetes.io/safe-to-evict" : "false"
    }
  })
}

data "utils_deep_merge_yaml" "values" {
  input = compact([
    local.values,
    var.values
  ])
}

output "values" {
  value = data.utils_deep_merge_yaml.values.output
  // sensitive = false
}
