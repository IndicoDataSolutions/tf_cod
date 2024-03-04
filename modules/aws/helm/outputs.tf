output "client_id" {
  value = data.keycloak_openid_client.kube-oidc-proxy.client_id
}

output "client_secret" {
  value     = data.keycloak_openid_client.kube-oidc-proxy.client_secret
  sensitive = true
}
