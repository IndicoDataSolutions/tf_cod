provider "null" {
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
}

provider "azapi" {
}

provider "http" {}

provider "time" {}

provider "vault" {
  address          = var.vault_address
  skip_child_token = true
  auth_login_userpass {
    username = var.vault_username
    password = var.vault_password
  }
}
provider "github" {
  token = var.git_pat
  owner = "IndicoDataSolutions"
}

provider "local" {}


# argo 
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host = local.kubernetes_host
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [local.kubernetes_host, local.kubeadmin_username, local.kubeadmin_password]
    command     = "./get_token.sh"
  }
}

provider "kubectl" {
  host = local.kubernetes_host
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [local.kubernetes_host, local.kubeadmin_username, local.kubeadmin_password]
    command     = "./get_token.sh"
  }
  load_config_file = true
}

provider "helm" {
  kubernetes {
    host = local.kubernetes_host
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = [local.kubernetes_host, local.kubeadmin_username, local.kubeadmin_password]
      command     = "./get_token.sh"
    }
  }
}
