
locals {
  openid_cluster_patch = jsonencode(<<JSON
    [
      {
        "op": "add",
        "path": "/spec/identityProviders",
        "value": 
        [
          {
            "mappingMethod": "claim",
            "name": "openid",
            "type": "OpenID",
            "openID": {
              "claims": {
                "email": ["${var.openid_emailclaim}"], 
                "groups": ["${var.openid_groups_claim}"],
                "name": ["name"],
                "preferredUsername": ["${var.openid_preferred_username}"],
              },
              "clientID": "${var.openid_client_id}",
              "clientSecret": {
                "name": "${var.openid_idp_name}-client-secret"
              }
              "issuer": "${var.openid_connect_issuer_url}"
            }
          }
        ]
      }
    ]
  JSON
  )
}
