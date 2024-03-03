data "keycloak_realm" "realm" {
  realm = "GoogleAuth"
}

data "keycloak_openid_client" "kube-oidc-proxy" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = "kube-oidc-proxy"
}

resource "null_resource" "register-callback" {
  # Ensure this runs only if we change these.
  triggers = {
    dns_name      = var.dns_name
    client_secret = data.keycloak_openid_client.kube-oidc-proxy.client_secret
  }
  # must use full resource def for the apply, but must use self.triggers for destroy
  # annoying: https://stackoverflow.com/questions/72820832/self-triggers-is-null-when-trying-to-use-trigger-values-in-local-exec-provisio
  provisioner "local-exec" {
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${data.keycloak_openid_client.kube-oidc-proxy.client_secret}\" -v https://keycloak-service.devops.indico.io/add --data '{\"url\": \"https://k8s.${var.dns_name}/oauth2/callback\"}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -XDELETE -H 'Content-Type: application/json' -H \"Authorization: Bearer ${self.triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/delete --data '{\"url\": \"https://k8s.${self.triggers.dns_name}/oauth2/callback\"}'"
  }

}

