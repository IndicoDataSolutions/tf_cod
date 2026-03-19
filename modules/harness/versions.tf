terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    utils = {
      source  = "cloudposse/utils"
      version = "2.3.0"
    }
  }
}
