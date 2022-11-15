resource "null_resource" "enable-oidc" {
  depends_on = [
    module.cluster,
    module.fsx-storage
  ]

  provisioner "local-exec" {
    command = "aws --region ${var.region} eks associate-identity-provider-config --cluster-name ${var.label} --oidc identityProviderConfigName=google-ws,issuerUrl=https://keycloak.devops.indico.io/auth/realms/GoogleAuth,clientId=kube-oidc-proxy,usernameClaim=sub,usernamePrefix=oidcuser:,groupsClaim=groups,groupsPrefix=oidcgroup:"
  }

}


resource "kubernetes_cluster_role_binding" "cod-role-bindings" {
  depends_on = [
    module.cluster
  ]

  count = var.oidc_enabled == true ? 1 : 0

  metadata {
    name = "oidc-cod-admins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:Engineering"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:QA"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:DevOps"
    api_group = "rbac.authorization.k8s.io"
  }
}




