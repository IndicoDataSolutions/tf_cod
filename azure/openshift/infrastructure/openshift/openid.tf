

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

resource "null_resource" "add-identity-provider" {
  count = var.do_setup_openid_connect == true ? 1 : 0

  depends_on = [
    kubernetes_secret.openid-client-secret
  ]

  triggers = {
    client_secret = var.openid_client_secret,
    callback_url  = local.callback_url
  }


  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${var.resource_group_name}"
  }

  provisioner "local-exec" {
    command = <<CMD
      echo ${local.openid_cluster_patch} > cluster-patch.json
      cat cluster-patch.json
      kubectl patch oauth cluster --type=json  --patch-file cluster-patch.json
    CMD
  }

  #  https://oauth-openshift.apps.dop1487-indico-dev-azure.eastus.aroapp.io/oauth2callback/openid
  #console-openshift-console.apps.dop1487-indico-dev-azure.eastus.aroapp.io
  provisioner "local-exec" {
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${null_resource.register-add-identity-provider.triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/add --data '{\"url\": \"${null_resource.register-add-identity-provider..triggers.callback_url}\"}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -XDELETE -H 'Content-Type: application/json' -H \"Authorization: Bearer ${null_resource.register-add-identity-provider..triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/delete --data '{\"url\": \"${null_resource.register-add-identity-provider..triggers.callback_url}\"}'"
  }

}

