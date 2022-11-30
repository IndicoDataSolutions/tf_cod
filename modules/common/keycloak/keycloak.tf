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

data "keycloak_openid_client" "kube-oidc-proxy" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = "kube-oidc-proxy"
}

resource "null_resource" "register-callback" {
  # Ensure this runs every time
  triggers = {
    dns_name      = var.local_dns_name
    client_secret = data.keycloak_openid_client.kube-oidc-proxy.client_secret
    build_number  = "${timestamp()}"
  }
  # must use full resource def for the apply, but must use self.triggers for destroy
  # annoying: https://stackoverflow.com/questions/72820832/self-triggers-is-null-when-trying-to-use-trigger-values-in-local-exec-provisio
  provisioner "local-exec" {
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${null_resource.register-callback.triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/add --data '{\"url\": \"https://k8s.${null_resource.register-callback.triggers.dns_name}/oauth2/callback\"}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -XDELETE -H 'Content-Type: application/json' -H \"Authorization: Bearer ${self.triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/delete --data '{\"url\": \"https://k8s.${self.triggers.dns_name}/oauth2/callback\"}'"
  }

}

