
data "keycloak_realm" "realm" {
  realm = "GoogleAuth"
}

resource "keycloak_openid_client" "k8s-keycloak-client" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = local.dns_name
  name      = local.dns_name
  enabled   = true

  standard_flow_enabled = true
  
  access_type = "CONFIDENTIAL"
  valid_redirect_uris = [
    "k8s.${local.dns_name}/oauth2/callback" # k8s dashboard
  ]

  login_theme = "keycloak"
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id            = data.keycloak_realm.realm.id
  client_id           = keycloak_openid_client.k8s-keycloak-client.id
  name                = "group-membership-mapper"
  claim_name          = "groups"
  add_to_id_token     = true
  add_to_userinfo     = true
  add_to_access_token = true

}
