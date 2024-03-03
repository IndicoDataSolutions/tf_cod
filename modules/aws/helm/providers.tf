terraform {
  required_providers {
    keycloak = {
      source = "mrparkers/keycloak"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
