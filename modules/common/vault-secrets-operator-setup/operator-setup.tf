

resource "kubernetes_service_account_v1" "example" {
  metadata {
    name = "terraform-example"
  }
  secret {
    name = kubernetes_secret_v1.example.metadata.0.name
  }
}

resource "kubernetes_secret_v1" "example" {
  metadata {
    name = "terraform-example"
  }
}


resource "kubernetes_service_account_v1" "vault-auth" {
  metadata {
    name = "vault-auth"
  }
}


resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = local.account_region_name
}


/*

resource "vault_kubernetes_auth_backend_config" "cluster-auth" {
  kubernetes_host        = var.kubernetes_host
  disable_iss_validation = "true"
  #  issuer="https://kubernetes.default.svc.cluster.local"
  token_reviewer_jwt = data.local_file.vault-token.content
  kubernetes_ca_cert = var.kubernetes_cluster_ca_certificate
}

*/
