

resource "azuread_application" "openshift-application" {
  display_name = "${var.label}-${var.region}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "openshift" {
  application_id               = azuread_application.openshift-application.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "application-secret" {
  display_name          = "openshift-sp-secret"
  application_object_id = azuread_application.openshift-application.object_id
}

resource "azurerm_role_assignment" "virtual-network-assignment" {
  depends_on = [
    module.networking
  ]
  count                = length(var.roles)
  scope                = module.networking.vnet_id
  role_definition_name = var.roles[count.index].role
  principal_id         = azuread_service_principal.openshift.object_id
}

resource "azurerm_role_assignment" "resource-provider-assignment" {
  depends_on = [
    module.networking
  ]
  count                = length(var.roles)
  scope                = module.networking.vnet_id
  role_definition_name = var.roles[count.index].role
  principal_id         = data.azuread_service_principal.redhat-openshift.object_id
}



module "argo-registration" {
  depends_on = [
    module.cluster
  ]

  count = var.argo_enabled == true ? 1 : 0

  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.1.12"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  account                      = var.account
  cloud_provider               = "azure"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = module.cluster.kubernetes_cluster_ca_certificate
}

locals {
  resource_group_name = "${var.label}-${var.region}"

  storage_account_name    = replace(lower("${var.account}snapshots"), "-", "")
  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")
  cluster_name            = var.label
  base_domain             = lower("${var.account}.${var.domain_suffix}")                            # indico-dev-azure.indico.io
  dns_prefix              = lower("${var.label}.${var.region}")                                     # os1.eastus
  dns_name                = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}") # os1.eastus.indico-dev-azure.indico.io
  infrastructure_id       = data.kubernetes_resource.infrastructure-cluster.object.status.infrastructureName
  machinesets = flatten([
    for key, group in var.openshift_machine_sets : {
      name                           = key
      pool_name                      = group.pool_name
      vm_size                        = group.vm_size
      node_os                        = group.node_os
      zones                          = group.zones
      taints                         = group.taints
      labels                         = group.labels
      cluster_auto_scaling_min_count = group.cluster_auto_scaling_min_count
      cluster_auto_scaling_max_count = group.cluster_auto_scaling_max_count
      storageAccountType             = group.storageAccountType
      image                          = group.image
    }
  ])
  kube_prometheus_stack_enabled = false
  indico_storage_class_name     = "azurefile"
}


resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_resource_group" "cod-cluster" {
  name     = local.resource_group_name
  location = var.region
}

module "networking" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source              = "app.terraform.io/indico/indico-azure-openshift-network/mod"
  version             = "1.0.1"
  label               = var.label
  vnet_cidr           = var.vnet_cidr
  subnet_cidrs        = var.subnet_cidrs
  worker_subnet_cidrs = var.worker_subnet_cidrs
  resource_group_name = local.resource_group_name
  region              = var.region
}

module "storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source              = "app.terraform.io/indico/indico-azure-blob/mod"
  version             = "0.1.7"
  label               = var.label
  region              = var.region
  resource_group_name = local.resource_group_name
}

module "cluster" {
  depends_on = [
    module.networking,
    azurerm_resource_group.cod-cluster
  ]
  source = "./modules/openshift-cluster"

  openshift-version   = var.openshift_version
  vault_path          = lower("${var.account}-${var.region}-${var.label}")
  vault_mount         = var.vault_mount_path
  subscriptionId      = split("/", data.azurerm_subscription.primary.id)[2]
  pull_secret         = var.openshift_pull_secret
  cluster_domain      = lower("${var.label}-${var.account}")
  label               = var.label
  region              = var.region
  svp_client_id       = azuread_service_principal.openshift.application_id
  svp_client_secret   = azuread_application_password.application-secret.value
  master_subnet_id    = module.networking.subnet_id
  worker_subnet_id    = module.networking.worker_subnet_id
  resource_group_name = local.resource_group_name

}

data "kubernetes_resource" "infrastructure-cluster" {
  depends_on = [
    module.cluster
  ]
  api_version = "config.openshift.io/v1"
  kind        = "Infrastructure"

  metadata {
    name = "cluster"
  }
}

output "infrastructure_id" {
  value = local.infrastructure_id
}


resource "kubernetes_storage_class" "default" {
  depends_on = [
    module.cluster
  ]

  metadata {
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
    name = "default"
    labels = {
      "addonmanager.kubernetes.io/mode" = "EnsureExists"
      "kubernetes.io/cluster-service"   = "true"
    }
  }
  allow_volume_expansion = true
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    skuname = "StandardSSD_LRS"
  }
}



# Install the Machinesets now
resource "helm_release" "openshift-crds" {
  depends_on = [
    module.cluster,
    data.kubernetes_resource.infrastructure-cluster
  ]

  verify           = false
  name             = "ipa-ms"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "openshift-crds"
  version          = var.ipa_openshift_crds_version
  timeout          = "600" # 10 minutes
  wait             = true

  values = [<<EOF
machineset:
  # oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster
  infrastructureId: ${local.infrastructure_id}
  region: ${var.region}
  networkResourceGroup: ${var.label}-${var.region}
  clusterResourceGroup: aro-${var.label}-${var.region}
  workerSubnetId: indico-worker-${var.label}-${var.region}
  vnetId: ${var.label}-vnet

machineSets:
${yamlencode(local.machinesets)}
  EOF
  ]
}
