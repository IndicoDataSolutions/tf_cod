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


resource "null_resource" "get-cluster-data" {

  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]

  # generates files in /tmp
  provisioner "local-exec" {
    command     = "${path.module}/get_cluster_data.sh ${var.label} ${var.resource_group_name}"
    interpreter = ["/bin/bash", "-c"]
  }
}


data "local_file" "sa_token" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_token"
}

data "local_file" "sa_cert" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_cert"
}


data "local_file" "sa_username" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_username"
}

data "local_file" "user_token" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/user_token"
}

data "local_file" "username" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/username"
}

data "local_file" "password" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/password"
}

data "local_file" "api_ip" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/api_ip"
}

data "local_file" "api_url" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/api_url"
}

data "local_file" "console_ip" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/console_ip"
}

data "local_file" "console_url" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/console_url"
}


