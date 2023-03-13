

resource "kubernetes_secret" "openid-client-secret" {
  count = var.do_setup_openid_connect == true ? 1 : 0


  metadata {
    name      = "${var.openid_idp_name}-client-secret"
    namespace = "openshift-config"

  }

  type = "Opaque"

  data = {
    "clientSecret" = var.openid_client_secret
  }
}

/* 
data "keycloak_realm" "realm" {
  count = var.do_setup_openid_connect == true ? 1 : 0
  realm = "GoogleAuth"
}

data "keycloak_openid_client" "kube-oidc-proxy" {
  count     = var.do_setup_openid_connect == true ? 1 : 0
  realm_id  = data.keycloak_realm.realm.id
  client_id = var.openid_client_id
} */

resource "null_resource" "add-identity-provider" {
  count = var.do_setup_openid_connect == true ? 1 : 0
  depends_on = [
    kubernetes_secret.openid-client-secret
  ]

  triggers = {
    always_run = "${timestamp()}"
  }


  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${var.resource_group_name}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<CMD
      kubectl patch oauth cluster --type=json -p='[{"op": "add", "path": "/spec/identityProviders", "value": "${var.openid_auth}"}]'
    CMD
  }
}
