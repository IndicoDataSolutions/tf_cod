terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dns-control]
    }
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

