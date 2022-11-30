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

resource "null_resource" "register-callback-test" {
  # Ensure this runs every time
  triggers = {
    build_number = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${data.keycloak_openid_client.kube-oidc-proxy.client_secret}\" -v https://keycloak-service.devops.indico.io/add --data '{\"url\": \"https://k8s.${local.dns_name}/oauth2/callback\"}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${data.keycloak_openid_client.kube-oidc-proxy.client_secret}\" -v https://keycloak-service.devops.indico.io/delete --data '{\"url\": \"https://k8s.${local.dns_name}/oauth2/callback\"}'"
  }

}

