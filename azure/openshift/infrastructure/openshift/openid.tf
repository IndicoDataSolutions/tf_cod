

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

  triggers = {
    callback_url  = local.callback_url
    client_secret = var.openid_client_secret
  }

  depends_on = [
    kubernetes_secret.openid-client-secret
  ]

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

  provisioner "local-exec" {
    command = "curl -XPOST -H 'Content-Type: application/json' -H \"Authorization: Bearer ${var.openid_client_secret}\" -v https://keycloak-service.devops.indico.io/add --data '{\"url\": \"${local.callback_url}\"}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -XDELETE -H 'Content-Type: application/json' -H \"Authorization: Bearer ${self.triggers.client_secret}\" -v https://keycloak-service.devops.indico.io/delete --data '{\"url\": \"${self.triggers.callback_url}\"}'"
  }

}

output "callbackurl" {
  value = resource.null_resource.add-identity-provider.0.triggers.callback_url
}


