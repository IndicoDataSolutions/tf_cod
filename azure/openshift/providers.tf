terraform {
  foobar = "ahoy there"
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
    vault = {
      source  = "hashicorp/vault"
      version = "3.13.0"
    }
  }
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

provider "local" {}


# argo 
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host                   = var.do_create_cluster == true ? module.create.0.kubernetes_host : var.kubernetes_host
  client_certificate     = var.do_create_cluster == true ? module.create.0.kubernetes_client_certificate : var.kubernetes_client_certificate
  client_key             = var.do_create_cluster == true ? module.create.0.kubernetes_client_key : var.kubernetes_client_key
  cluster_ca_certificate = var.do_create_cluster == true ? module.create.0.kubernetes_cluster_ca_certificate : var.kubernetes_cluster_ca_certificate
}

provider "kubectl" {
  host                   = var.do_create_cluster == true ? module.create.0.kubernetes_host : var.kubernetes_host
  client_certificate     = var.do_create_cluster == true ? module.create.0.kubernetes_client_certificate : var.kubernetes_client_certificate
  client_key             = var.do_create_cluster == true ? module.create.0.kubernetes_client_key : var.kubernetes_client_key
  cluster_ca_certificate = var.do_create_cluster == true ? module.create.0.kubernetes_cluster_ca_certificate : var.kubernetes_cluster_ca_certificate
  load_config_file       = false
}


provider "helm" {
  debug = true
  kubernetes {
    host                   = var.do_create_cluster == true ? module.create.0.kubernetes_host : var.kubernetes_host
    client_certificate     = var.do_create_cluster == true ? module.create.0.kubernetes_client_certificate : var.kubernetes_client_certificate
    client_key             = var.do_create_cluster == true ? module.create.0.kubernetes_client_key : var.kubernetes_client_key
    cluster_ca_certificate = var.do_create_cluster == true ? module.create.0.kubernetes_cluster_ca_certificate : var.kubernetes_cluster_ca_certificate
  }
}


