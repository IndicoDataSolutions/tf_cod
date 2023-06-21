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
