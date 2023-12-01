terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 0.14.0"
    }
  }
}