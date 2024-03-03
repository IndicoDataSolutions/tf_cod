terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}
