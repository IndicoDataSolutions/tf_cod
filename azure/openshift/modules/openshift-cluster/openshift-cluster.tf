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

resource "null_resource" "create-user" {
  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [
    azurerm_resource_group_template_deployment.openshift-cluster
  ]

  # generates files in /tmp
  provisioner "local-exec" {
    command     = "${path.module}/create-user.sh ${var.label} ${var.resource_group_name}"
    interpreter = ["/bin/bash", "-c"]
  }
}

data "local_file" "openshift_console_ip" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.openshift_console_ip"
}

data "local_file" "openshift_api_ip" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.openshift_api_ip"
}

data "local_file" "kubernetes_host" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.kubernetes_host"
}

data "local_file" "kubernetes_client_certificate" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.kubernetes_client_certificate"
}

data "local_file" "kubernetes_client_key" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.kubernetes_client_key"
}

data "local_file" "kubernetes_cluster_ca_certificate" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.kubernetes_cluster_ca_certificate"
}

data "local_file" "kube_config_file" {
  depends_on = [
    null_resource.create-user
  ]
  filename = "/tmp/${var.label}-${var.resource_group_name}.kube_config"
}


# missing:
# kubernetes_client_certificate
# kubernetes_cluster_ca_certificate
# kubernetes_host

resource "vault_kv_secret_v2" "kubernetes-credentials" {
  mount = "terraform"
  name  = var.vault_path
  data_json = jsonencode(
    {
      kubernetes_host                   = trimspace(data.local_file.kubernetes_host.content),
      kubernetes_client_certificate     = data.local_file.kubernetes_client_certificate.content,
      kubernetes_client_key             = data.local_file.kubernetes_client_key.content,
      kubernetes_cluster_ca_certificate = base64decode(data.local_file.kubernetes_cluster_ca_certificate.content),
      api_ip                            = data.local_file.openshift_api_ip.content,
      console_ip                        = data.local_file.openshift_console_ip.content
    }
  )
  lifecycle {
    ignore_changes = [
      data_json
    ]
  }
}

data "vault_kv_secret_v2" "kubernetes-credentials" {
  depends_on = [
    vault_kv_secret_v2.kubernetes-credentials
  ]
  mount = "terraform"
  name  = var.vault_path
}
