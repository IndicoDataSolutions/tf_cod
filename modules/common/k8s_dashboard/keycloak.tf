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
  }
}

data "keycloak_realm" "realm" {
  realm = "GoogleAuth"
}

resource "keycloak_openid_client" "k8s-keycloak-client" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = var.local_dns_name
  name      = var.local_dns_name
  enabled   = true

  standard_flow_enabled = true

  access_type = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://k8s.${var.local_dns_name}/oauth2/callback" # k8s dashboard
  ]

  frontchannel_logout_enabled = true
  frontchannel_logout_url     = "https://k8s.${var.local_dns_name}/oauth2/sign_out"

  login_theme = "keycloak"
}

resource "keycloak_openid_client_scope" "client_scope" {
  realm_id = data.keycloak_realm.realm.id
  name     = "k8s-client-scope"
}

resource "keycloak_openid_client_default_scopes" "client_default_scopes" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = keycloak_openid_client.k8s-keycloak-client

  default_scopes = [
    "profile",
    "email",
    "groups",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.client_scope.name,
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id            = data.keycloak_realm.realm.id
  client_id           = keycloak_openid_client.k8s-keycloak-client.id
  name                = "group-membership-mapper"
  claim_name          = "groups"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true
  full_path           = false

}
