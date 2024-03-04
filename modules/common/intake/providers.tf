terraform {
  required_providers {
    argocd = {
      source = "oboukili/argocd"
    }
    github = {
      source = "integrations/github"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
