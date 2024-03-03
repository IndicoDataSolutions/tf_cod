terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    helm = {
      source = "hashicorp/helm"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}
