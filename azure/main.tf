terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.40.0"
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
      version = ">= 2.12.1"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
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
  features {}
}

provider "azurerm" {
  features {}
  alias           = "readapi"
  client_id       = var.azure_readapi_client_id
  client_secret   = var.azure_readapi_client_secret
  subscription_id = var.azure_readapi_subscription_id
  tenant_id       = var.azure_readapi_tenant_id
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


provider "helm" {
  debug = true
  kubernetes {
    host                   = module.cluster.kubernetes_host
    client_certificate     = module.cluster.kubernetes_client_certificate
    client_key             = module.cluster.kubernetes_client_key
    cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  }
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
  version                      = "1.1.16"
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
}

provider "local" {}

locals {
  resource_group_name = "${var.label}-${var.region}"

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
  source              = "app.terraform.io/indico/indico-azure-network/mod"
  version             = "3.0.5"
  label               = var.label
  vnet_cidr           = var.vnet_cidr
  subnet_cidrs        = var.subnet_cidrs
  resource_group_name = local.resource_group_name
  region              = var.region
}

module "storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source               = "app.terraform.io/indico/indico-azure-blob/mod"
  version              = "0.1.14"
  label                = var.label
  region               = var.region
  resource_group_name  = local.resource_group_name
  storage_account_name = local.storage_account_name
}

module "cluster" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]

  source                     = "app.terraform.io/indico/indico-azure-cluster/mod"
  insights_retention_in_days = var.monitor_retention_in_days
  version                    = "3.1.4"
  label                      = var.label
  public_key                 = tls_private_key.pk.public_key_openssh
  region                     = var.region
  svp_client_id              = var.svp_client_id
  svp_client_secret          = var.svp_client_secret
  default_node_pool          = var.default_node_pool
  additional_node_pools      = var.additional_node_pools
  vnet_subnet_id             = module.networking.subnet_id
  k8s_version                = var.k8s_version
  private_cluster_enabled    = var.private_cluster_enabled
  resource_group_name        = local.resource_group_name
  admin_group_name           = var.admin_group_name
  account                    = var.account
  # this feature can be checked using:
  # az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"
  # az provider register --namespace Microsoft.ContainerService
  enable_workload_identity = true # requires: az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
  enable_oidc_issuer       = true
}

module "readapi_queue" {
  count = var.enable_readapi ? 1 : 0
  providers = {
    azurerm = azurerm.readapi
  }
  source       = "app.terraform.io/indico/indico-azure-readapi-queue/mod"
  version      = "1.0.0"
  readapi_name = lower("${var.account}-${var.label}")
}

locals {
  readapi_secret_path = var.environment == "production" ? "prod-readapi" : "dev-readapi"
}

data "vault_kv_secret_v2" "readapi_secret" {
  mount = "customer-${var.account}"
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
  count                   = var.enable_servicebus == true ? 1 : 0
  source                  = "app.terraform.io/indico/indico-azure-servicebus/mod"
  version                 = "1.1.1"
  label                   = var.label
  resource_group_name     = azurerm_resource_group.cod-cluster.name
  region                  = var.region
  svp_client_id           = var.svp_client_id
  servicebus_pricing_tier = var.servicebus_pricing_tier
  workload_identity_id    = azuread_service_principal.workload_identity.id
}

