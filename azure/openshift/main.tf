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
      version = "4.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.2.3"
    }
    github = {
      source  = "integrations/github"
      version = "4.26.0"
    }
  }
}

provider "azurerm" {
  features {}
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

data "http" "workstation-external-ip" {
  url = "http://ipv4.icanhazip.com"
}

data "azuread_service_principal" "redhat-openshift" {
  display_name = "Azure Red Hat OpenShift RP"
}
/*
resource "null_resource" "install_azure_cli" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command     = <<EOH
     az version
     env|sort
     az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
     az aro list-credentials --name ${var.label} --resource-group ${local.resource_group_name} --output json
    EOH
    interpreter = ["/bin/bash", "-c"]
  }
}


module "get-kube-credentials" {
  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
    az aro list-credentials --name ${var.label} --resource-group ${local.resource_group_name} --output json
  EOH
}
*/

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
  display_name          = "terraform-sa-secret"
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

# argo 
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host  = module.cluster.kubernetes_host
  token = module.cluster.kubernetes_token
}

provider "kubectl" {
  host             = module.cluster.kubernetes_host
  token            = module.cluster.kubernetes_token
  load_config_file = false
}


provider "helm" {
  debug = true
  kubernetes {
    host  = module.cluster.kubernetes_host
    token = module.cluster.kubernetes_token
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
  version                      = "1.1.11"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  account                      = var.account
  cloud_provider               = "azure"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = data.kubernetes_secret.deployer.data["ca.crt"]
}

provider "local" {}

locals {
  resource_group_name = "${var.label}-${var.region}"
  current_ip          = "${chomp(data.http.workstation-external-ip.response_body)}/20"

  storage_account_name    = replace(lower("${var.account}snapshots"), "-", "")
  argo_app_name           = lower("${var.account}.${var.region}.${var.label}-ipa")
  argo_cluster_name       = "${var.account}.${var.region}.${var.label}"
  argo_smoketest_app_name = lower("${var.account}.${var.region}.${var.label}-smoketest")

  cluster_name = var.label
  base_domain  = lower("${var.account}.${var.domain_suffix}")
  dns_prefix   = lower("${var.label}.${var.region}")
  dns_name     = lower("${var.label}.${var.region}.${var.account}.${var.domain_suffix}")
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
  version             = "0.1.5"
  label               = var.label
  region              = var.region
  resource_group_name = local.resource_group_name
}


data "vault_kv_secret_v2" "terraform-redhat" {
  mount = "terraform"
  name  = "redhat"
}

module "cluster" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  pull_secret       = jsondecode(data.vault_kv_secret_v2.terraform-redhat.data_json)["openshift-pull-secret"]
  cluster_domain    = local.dns_name
  source            = "./modules/openshift-cluster"
  label             = var.label
  region            = var.region
  svp_client_id     = azuread_service_principal.openshift.application_id
  svp_client_secret = azuread_application_password.application-secret.value
  #default_node_pool       = var.default_node_pool
  #additional_node_pools   = var.additional_node_pools
  master_subnet_id = module.networking.subnet_id
  worker_subnet_id = module.networking.worker_subnet_id
  #k8s_version             = var.k8s_version
  #private_cluster_enabled = var.private_cluster_enabled
  resource_group_name = local.resource_group_name
  #admin_group_name        = var.admin_group_name
  # this feature can be checked using:
  # az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"
  # az provider register --namespace Microsoft.ContainerService
  #enable_workload_identity = true # requires: az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
  #enable_oidc_issuer       = true
}


data "kubernetes_service_account_v1" "deployer" {
  depends_on = [
    module.cluster
  ]
  metadata {
    name      = "deployer"
    namespace = "default"
  }
}



data "kubernetes_secret" "deployer" {
  depends_on = [
    module.cluster
  ]
  metadata {
    name      = data.kubernetes_service_account_v1.deployer.default_secret_name
    namespace = "default"
  }
}

output "deployer" {
  value = data.kubernetes_service_account_v1.deployer.default_secret_name
}

output "cluster_ca_certificate" {
  sensitive = true
  value     = data.kubernetes_secret.deployer.data["ca.crt"]
}
