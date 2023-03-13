
locals {
  nfd_namespace             = var.nfd_namespace
  nvidia_operator_namespace = var.nvidia_operator_namespace
  package                   = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
  channel                   = data.kubernetes_resource.package.object.status.defaultChannel
  infrastructure_id         = data.kubernetes_resource.infrastructure-cluster.object.status.infrastructureName
  machinesets = flatten([
    for key, group in var.openshift_machine_sets : {
      name                           = key
      pool_name                      = group.pool_name
      vm_size                        = group.vm_size
      node_os                        = group.node_os
      zones                          = group.zones
      taints                         = group.taints
      labels                         = group.labels
      cluster_auto_scaling_min_count = group.cluster_auto_scaling_min_count
      cluster_auto_scaling_max_count = group.cluster_auto_scaling_max_count
      storageAccountType             = group.storageAccountType
      image                          = group.image
    }
  ])


  openid_client_id          = var.do_setup_openid_connect == true ? jsondecode(data.vault_kv_secret_v2.keycloak.0.data_json)["client"] : ""
  openid_client_secret      = var.do_setup_openid_connect == true ? jsondecode(data.vault_kv_secret_v2.keycloak.0.data_json)["clientSecret"] : ""
  openid_connect_issuer_url = var.do_setup_openid_connect == true ? jsondecode(data.vault_kv_secret_v2.keycloak.0.data_json)["issuerURL"] : ""

  openid_auth = jsonencode(yamldecode(<<YAML
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
          name: "${var.openid_idp_name}-client-secret"
  YAML
  ))
}

