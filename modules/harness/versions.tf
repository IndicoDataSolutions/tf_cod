terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 0.14.0"
    }
  }
}