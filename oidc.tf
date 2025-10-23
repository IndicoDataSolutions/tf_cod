resource "null_resource" "enable-oidc" {
  depends_on = [
    module.cluster,
    module.fsx-storage
  ]

  count = var.multitenant_enabled == false ? 1 : 0

  provisioner "local-exec" {
    command = "aws --region ${var.region} eks associate-identity-provider-config --cluster-name ${var.label} --oidc identityProviderConfigName=google-ws,issuerUrl=https://keycloak.devops.indico.io/auth/realms/GoogleAuth,clientId=kube-oidc-proxy,usernameClaim=sub,usernamePrefix=oidcuser:,groupsClaim=groups,groupsPrefix=oidcgroup:"
  }

}

resource "kubernetes_cluster_role_binding" "cod-role-bindings" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]

  count = var.oidc_enabled == true && strcontains(lower(var.aws_account), "indico-") && var.multitenant_enabled == false ? 1 : 0

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
    name      = "oidcgroup:engineering@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:qa@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:devops@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding" "eng-qa-rbac-bindings" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]

  count = var.oidc_enabled == true && strcontains(lower(var.aws_account), "indico-") && var.multitenant_enabled == false ? 1 : 0

  metadata {
    name = "oidc-cod-eng-qa-admins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:engineering@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:qa@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding" "devops-rbac-bindings" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]

  count = var.oidc_enabled == true && var.multitenant_enabled == false ? 1 : 0

  metadata {
    name = "oidc-cod-devops-admins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "oidcgroup:devops@indico.io"
    api_group = "rbac.authorization.k8s.io"
  }
}


