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
      version = ">= 2.17.0"
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
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}


variable "label" {
  default = "os8"
}

locals {
  resource_group_name = "os8-eastus"
}

provider "null" {
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
}

provider "azapi" {
}


data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}


provider "kubernetes" {
  host = module.cluster.kubernetes_url

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [var.label, local.resource_group_name]
    command     = "./get_token.sh"
  }
}

provider "kubectl" {
  host = module.cluster.kubernetes_url

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [var.label, local.resource_group_name]
    command     = "./get_token.sh"
  }

  load_config_file = false
}

provider "helm" {
  debug = true
  kubernetes {
    host = module.cluster.kubernetes_url

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = [var.label, local.resource_group_name]
      command     = "./get_token.sh"
    }
  }
}


module "cluster" {
  source              = "./modules/openshift"
  label               = var.label
  resource_group_name = local.resource_group_name
}

data "kubernetes_service_account_v1" "deployer" {
  depends_on = [module.cluster]
  metadata {
    name      = "deployer"
    namespace = "default"
  }
}

data "kubernetes_secret" "deployer" {

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
  value     = base64encode(data.kubernetes_secret.deployer.data["ca.crt"])
}


output "kubernetes_url" {
  value = module.cluster.kubernetes_url
}

output "sa_username" {
  value = module.cluster.kubernetes_sa_username
}

output "sa_token" {
  value = module.cluster.kubernetes_sa_token
}

output "kubernetes_token" {
  value = module.cluster.kubernetes_token
}




