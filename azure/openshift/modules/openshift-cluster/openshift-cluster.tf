# Deploy ARO using ARM template

resource "azurerm_resource_group_template_deployment" "openshift-cluster" {
  name                = var.label
  resource_group_name = var.resource_group_name

  template_content = file("${path.module}/ARM-openShiftClusters.json")

  parameters_content = jsonencode({
    "clientId"                 = var.svp_client_id
    "clientSecret"             = var.svp_client_secret
    "clusterName"              = var.label
    "clusterResourceGroupName" = lower("aro-${var.label}-${var.region}")
    "domain"                   = var.cluster_domain
    "location"                 = var.region
    "masterSubnetId"           = var.master_subnet_id
    "pullSecret"               = var.pull_secret
    "tags"                     = jsonencode(var.tags)
    "workerSubnetId"           = var.worker_subnet_id
  })

  deployment_mode = "Incremental"
}

module "shell-kube-credentials" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]
  source       = "Invicton-Labs/shell-data/external"
  command_unix = "az aro list-credentials --name ${var.label} --resource-group ${var.resource_group_name} --output json"
}

module "shell-kube-host" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]

  source       = "Invicton-Labs/shell-data/external"
  command_unix = "az aro show --name ${var.label} --resource-group ${var.resource_group_name} --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json"
}

module "shell-oc-login" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster,
    module.shell-kube-credentials
  ]

  fail_on_nonzero_exit_code = true

  source = "Invicton-Labs/shell-data/external"
  environment = {
    KUBECONFIG = "${path.module}/.openshift-config"
  }

  command_unix = "oc login --username ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminUsername"]} --password ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminPassword"]} --server ${jsondecode(module.shell-kube-credentials.stdout)["apiUrl"]}"
}

data "local_file" "kubeconfig" {
  depends_on = [
    module.shell-oc-login
  ]
  filename = "${path.module}/.openshift-config"
}









