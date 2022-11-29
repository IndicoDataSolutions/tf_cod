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

  provisioner "local-exec" {
    command = "echo 'create register-callback'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'destroy register-callback'"
  }

}

