terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dns-control]
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}