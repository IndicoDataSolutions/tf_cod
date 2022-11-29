terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.18.0"
    }
  }
}

provider "restapi" {
  alias                = "restapi_headers"
  uri                  = "https://httpbin.org"
  debug                = true
  write_returns_object = true

  headers = {
    X-Internal-Client = "abc123"
    Authorization     = "foobar"
  }
}

data "keycloak_realm" "realm" {
  realm = "GoogleAuth"
}

data "keycloak_openid_client" "kube-oidc-proxy" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = "kube-oidc-proxy"
}

