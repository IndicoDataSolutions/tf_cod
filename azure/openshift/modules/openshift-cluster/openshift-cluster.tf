# Deploy ARO using ARM template


resource "azurerm_resource_group_template_deployment" "openshift-cluster" {
  name                = "${var.label}-deployment"
  resource_group_name = var.resource_group_name

  template_content = file("${path.module}/ARM-openShiftClusters.json")

  parameters_content = jsonencode({
    "clientId"                 = { value = var.svp_client_id }
    "clientSecret"             = { value = var.svp_client_secret }
    "clusterName"              = { value = var.label }
    "clusterResourceGroupId"   = { value = "/subscriptions/${var.subscriptionId}/resourceGroups/${lower("aro-${var.label}-${var.region}")}" }
    "clusterResourceGroupName" = { value = lower("aro-${var.label}-${var.region}") }
    "domain"                   = { value = var.cluster_domain }
    "location"                 = { value = var.region }
    "masterSubnetId"           = { value = var.master_subnet_id }
    "pullSecret"               = { value = var.pull_secret }
    "tags"                     = { value = jsonencode(var.tags) }
    "workerSubnetId"           = { value = var.worker_subnet_id }
  })

  deployment_mode = "Incremental"

  lifecycle {
    ignore_changes = [
      template_content,
      parameters_content
    ]
  }
}

module "shell-kube-credentials" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]
  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro list-credentials --name ${var.label} --resource-group ${var.resource_group_name} --output json
  EOH
}

module "shell-kube-host" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]

  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro show --name ${var.label} --resource-group ${var.resource_group_name} --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json
  EOH
}

module "shell-oc-login" {
  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster,
    module.shell-kube-credentials
  ]

  fail_on_nonzero_exit_code = false

  source = "Invicton-Labs/shell-data/external"
  environment = {
    KUBECONFIG = "/tmp/.openshift-config"
  }

  command_unix = <<EOH
    oc login ${jsondecode(module.shell-kube-host.stdout)["apiUrl"]} --username ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminUsername"]} --password ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminPassword"]} > /dev/null
    if [ $? -ne 0 ]; then
      echo "{users: [{user: {token: INVALID}}]}" > /tmp/.openshift-config
    fi
  EOH
}

data "local_file" "kubeconfig" {
  depends_on = [
    module.shell-oc-login
  ]
  filename = "/tmp/.openshift-config"
}









