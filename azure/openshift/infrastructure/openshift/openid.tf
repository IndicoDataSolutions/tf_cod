

resource "kubernetes_secret" "openid-client-secret" {
  count = var.do_setup_openid_connect == true ? 1 : 0


  metadata {
    name      = "${var.openid_idp_name}-client-secret"
    namespace = "openshift-config"

  }

  type = "Opaque"

  data = {
    "clientSecret" = "foobar"
  }
}

resource "kubectl_manifest" "oauth" {
  count = var.do_setup_openid_connect == true ? 1 : 0
  depends_on = [
    kubernetes_secret.openid-client-secret
  ]

  yaml_body = <<YAML
    apiVersion: "config.openshift.io/v1"
    kind: "Oauth"
    metadata:
      name: ${var.openid_idp_name}
     
    spec:
      identityProviders:
        - mappingMethod: claim
          name: openid
          openID:
            claims:
              email:
                - ${var.openid_emailclaim}
              groups:
                - ${var.openid_groups_claim}
              name:
                - name
              preferredUsername:
                - ${var.openid_preferred_username}
            clientId: ${var.openid_client_id}
            clientSecret:
              name: ${kubernetes_secret.openid-client-secret.0.metadata.0.name}
  YAML
}
