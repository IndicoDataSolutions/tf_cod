terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.106.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.33.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">=1.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "5.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.2.3"
    }
    github = {
      source  = "integrations/github"
      version = "4.26.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.13.0"
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
  alias           = "readapi"
  client_id       = var.azure_readapi_client_id
  client_secret   = var.azure_readapi_client_secret
  subscription_id = var.azure_readapi_subscription_id
  tenant_id       = var.azure_readapi_tenant_id
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
  alias           = "indicoio"
  client_id       = var.azure_indico_io_client_id
  client_secret   = var.azure_indico_io_client_secret
  subscription_id = var.azure_indico_io_subscription_id
  tenant_id       = var.azure_indico_io_tenant_id
}

provider "azuread" {
}

provider "azapi" {
}

provider "http" {}

provider "time" {}

provider "vault" {
  address          = var.vault_address
  skip_child_token = true
  auth_login_userpass {
    username = var.vault_username
    password = var.vault_password
  }
}

provider "github" {
  token = var.git_pat
  owner = "IndicoDataSolutions"
}
data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}


# argo 
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host                   = module.cluster.kubernetes_host
  client_certificate     = module.cluster.kubernetes_client_certificate
  client_key             = module.cluster.kubernetes_client_key
  cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
}

provider "kubectl" {
  host                   = module.cluster.kubernetes_host
  client_certificate     = module.cluster.kubernetes_client_certificate
  client_key             = module.cluster.kubernetes_client_key
  cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  load_config_file       = false
}

provider "kubectl" {
  alias                  = "devops-tools"
  host                   = var.devops_tools_cluster_host
  cluster_ca_certificate = var.devops_tools_cluster_ca_certificate
  #token                  = module.cluster.kubernetes_token
  load_config_file = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}

provider "helm" {
  debug = true
  kubernetes {
    host                   = module.cluster.kubernetes_host
    client_certificate     = module.cluster.kubernetes_client_certificate
    client_key             = module.cluster.kubernetes_client_key
    cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  }
}


provider "aws" {
  access_key                  = var.indico_devops_aws_access_key_id
  secret_key                  = var.indico_devops_aws_secret_access_key
  region                      = var.indico_devops_aws_region
  alias                       = "aws-indico-devops"
  skip_credentials_validation = var.thanos_enabled == true ? false : true
  skip_requesting_account_id  = var.thanos_enabled == true ? false : true
  skip_metadata_api_check     = var.thanos_enabled == true ? false : true
}

data "aws_eks_cluster" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

data "aws_eks_cluster_auth" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

provider "kubectl" {
  alias                  = "thanos-kubectl"
  host                   = var.thanos_enabled == true ? data.aws_eks_cluster.thanos[0].endpoint : ""
  cluster_ca_certificate = var.thanos_enabled == true ? base64decode(data.aws_eks_cluster.thanos[0].certificate_authority[0].data) : ""
  token                  = var.thanos_enabled == true ? data.aws_eks_cluster_auth.thanos[0].token : ""
  load_config_file       = false
}


module "argo-registration" {
  depends_on = [
    module.cluster
  ]

  count = var.argo_enabled == true ? 1 : 0

  providers = {
    kubernetes = kubernetes,
    argocd     = argocd
  }
  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.2.2"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  argo_namespace               = var.argo_namespace
  account                      = var.account
  cloud_provider               = "azure"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = module.cluster.kubernetes_cluster_ca_certificate
  indico_dev_cluster           = var.account == "indico-dev-azure"
}

provider "local" {}

locals {
  resource_group_name         = coalesce(var.resource_group_name, "${var.label}-${var.region}")
  network_resource_group_name = var.network_type == "load" ? var.network_resource_group_name : local.resource_group_name

  sentinel_workspace_name                = coalesce(var.sentinel_workspace_name, "${var.account}-sentinel-workspace")
  sentinel_workspace_resource_group_name = coalesce(var.sentinel_workspace_resource_group_name, "${var.account}-sentinel-group")

  snapshot_storage_account_name = replace(lower("${var.account}snapshots"), "-", "")
  storage_account_name          = replace(lower(var.storage_account_name), "-", "")

  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")

  cluster_name = var.label
  base_domain  = lower("${var.account}.${var.domain_suffix}")
  dns_prefix   = lower("${var.label}.${var.region}")
  dns_name     = var.domain_host == "" ? lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}") : var.domain_host

  kube_prometheus_stack_enabled = true

  indico_storage_class_name = "azurefile"
  ipa_version               = var.ipa_version
  argo_branch               = var.argo_branch
  argo_path                 = var.argo_path
  argo_repo                 = var.argo_repo
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_resource_group" "cod-cluster" {
  count    = var.create_resource_group == true ? 1 : 0
  name     = local.resource_group_name
  location = var.region
}


module "networking" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source               = "app.terraform.io/indico/indico-azure-network/mod"
  network_type         = var.network_type
  version              = "4.0.2"
  label                = var.label
  vnet_cidr            = var.vnet_cidr
  subnet_cidrs         = var.subnet_cidrs
  resource_group_name  = local.network_resource_group_name
  region               = var.region
  virtual_network_name = var.virtual_network_name
  virtual_subnet_name  = var.virtual_subnet_name
}

module "storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source                       = "app.terraform.io/indico/indico-azure-blob/mod"
  version                      = "1.0.1"
  label                        = var.label
  region                       = var.region
  resource_group_name          = local.resource_group_name
  storage_account_name         = local.storage_account_name
  keyvault_name                = var.keyvault_name
  blob_type                    = var.blob_type
  fileshare_name_override      = var.fileshare_name_override
  blob_store_name_override     = var.blob_store_name_override
  crunchy_backup_name_override = var.crunchy_backup_name_override
}

resource "azurerm_user_assigned_identity" "cluster_dns" {
  count               = var.private_dns_zone_id == "System" ? 0 : 1
  name                = "cluster_dns-identity"
  resource_group_name = local.resource_group_name
  location            = var.region
}

resource "azurerm_role_assignment" "example" {
  count                = var.private_dns_zone_id == "System" ? 0 : 1
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster_dns[0].principal_id
}

module "cluster" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]

  source                       = "app.terraform.io/indico/indico-azure-cluster/mod"
  insights_retention_in_days   = var.monitor_retention_in_days
  version                      = "4.2.5"
  label                        = var.label
  public_key                   = tls_private_key.pk.public_key_openssh
  region                       = var.region
  svp_client_id                = var.svp_client_id
  svp_client_secret            = var.svp_client_secret
  default_node_pool            = var.default_node_pool
  additional_node_pools        = var.additional_node_pools
  vnet_subnet_id               = module.networking.subnet_id
  k8s_version                  = var.k8s_version
  private_cluster_enabled      = var.private_cluster_enabled
  private_cluster_dns_override = var.private_cluster_dns_override
  resource_group_name          = local.resource_group_name
  admin_group_name             = var.admin_group_name
  account                      = var.account

  network_plugin                      = var.network_plugin
  network_plugin_mode                 = var.network_plugin_mode
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  cluster_outbound_type               = var.cluster_outbound_type
  private_dns_zone_id                 = var.private_dns_zone_id
  sku_tier                            = var.sku_tier
  service_cidr                        = var.cluster_service_cidr
  dns_service_ip                      = var.dns_service_ip
  docker_bridge_cidr                  = var.docker_bridge_cidr

  identity_ids = var.private_dns_zone_id == "System" ? [] : [azurerm_user_assigned_identity.cluster_dns[0].id]

  aks_storage_account_name = var.aks_storage_account_name

  sentinel_workspace_name                = local.sentinel_workspace_name
  sentinel_workspace_resource_group_name = local.sentinel_workspace_resource_group_name
  sentinel_workspace_id                  = var.sentinel_workspace_id

  # this feature can be checked using:
  # az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"
  # az provider register --namespace Microsoft.ContainerService
  enable_workload_identity = var.use_workload_identity # requires: az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
  enable_oidc_issuer       = true
}

module "readapi_queue" {
  count = var.enable_readapi ? 1 : 0
  providers = {
    azurerm = azurerm.readapi
  }
  source                        = "app.terraform.io/indico/indico-azure-readapi-queue/mod"
  version                       = "1.1.1"
  label                         = var.label
  account                       = var.account
  readapi_type                  = var.readapi_type
  readapi_name_override         = var.readapi_name_override
  azure_resource_group_override = var.readapi_azure_resource_group_override
  readapi_queue_name_override   = var.readapi_queue_name_override
}

locals {
  readapi_secret_path       = var.environment == "production" ? "prod-readapi" : "dev-readapi"
  customer_vault_mount_path = "customer-${coalesce(var.vault_mount_path, var.account)}"
}

data "vault_kv_secret_v2" "readapi_secret" {
  mount = local.customer_vault_mount_path
  name  = local.readapi_secret_path
}

resource "kubernetes_secret" "readapi" {
  count      = var.enable_readapi ? 1 : 0
  depends_on = [module.cluster]
  metadata {
    name = "readapi-secret"
  }

  data = {
    billing                       = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_url"]
    apikey                        = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_key"]
    READAPI_COMPUTER_VISION_HOST  = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_url"]
    READAPI_COMPUTER_VISION_KEY   = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_key"]
    READAPI_FORM_RECOGNITION_HOST = data.vault_kv_secret_v2.readapi_secret.data["form_recognizer_api_url"]
    READAPI_FORM_RECOGNITION_KEY  = data.vault_kv_secret_v2.readapi_secret.data["form_recognizer_api_key"]
    storage_account_name          = module.readapi_queue[0].storage_account_name
    storage_account_id            = module.readapi_queue[0].storage_account_id
    storage_account_access_key    = module.readapi_queue[0].storage_account_access_key
    storage_queue_name            = module.readapi_queue[0].storage_queue_name
    QUEUE_CONNECTION_STRING       = module.readapi_queue[0].storage_connection_string
  }
}

module "servicebus" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  count                              = var.use_workload_identity == true && var.enable_servicebus == true ? 1 : 0
  source                             = "app.terraform.io/indico/indico-azure-servicebus/mod"
  version                            = "1.2.1"
  label                              = var.label
  resource_group_name                = local.resource_group_name
  region                             = var.region
  svp_client_id                      = var.svp_client_id
  servicebus_pricing_tier            = var.servicebus_pricing_tier
  workload_identity_id               = azuread_service_principal.workload_identity.0.id
  servicebus_type                    = var.servicebus_type
  servicebus_namespace_name_override = var.servicebus_namespace_name_override
  servicebus_queue_name_override     = var.servicebus_queue_name_override
  servicebus_topic_name_override     = var.servicebus_topic_name_override
}

