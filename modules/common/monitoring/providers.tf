terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source                = "gavinbunney/kubectl"
      configuration_aliases = [kubectl.thanos-kubectl]
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

