terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.40.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.33.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">=1.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.17.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "4.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.2.3"
    }
    github = {
      source  = "integrations/github"
      version = "4.26.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}
variable "region" { default = "eastus" }
variable "restore_snapshot_enabled" {
  type    = bool
  default = false
}
variable "label" {
  default = "os8"
}

locals {
  resource_group_name = "os8-eastus"
}

variable "harbor_pull_secret_b64" {
  default = "ewogICJhdXRocyI6IHsKICAgICJodHRwczovL2hhcmJvci5kZXZvcHMuaW5kaWNvLmlvIjogewogICAgICAiYXV0aCI6ICJjbTlpYjNRa2FXMWhaMlV0Y0hWc2JDMXpaV055WlhRNk9URnROV0ZqV2taSVREZFhOM1EzYlRaVlMzVkdOMDlMU0ZkSVlscENNMWM9IgogICAgfQogIH0KfQ==pwd"
}

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


data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}


provider "kubernetes" {
  host = module.cluster.kubernetes_url

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [var.label, local.resource_group_name]
    command     = "./get_token.sh"
  }
}

provider "kubectl" {
  host = module.cluster.kubernetes_url

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [var.label, local.resource_group_name]
    command     = "./get_token.sh"
  }

  load_config_file = false
}

provider "helm" {
  debug = true
  kubernetes {
    host = module.cluster.kubernetes_url

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = [var.label, local.resource_group_name]
      command     = "./get_token.sh"
    }
  }
}


module "cluster" {
  source              = "./modules/openshift"
  label               = var.label
  resource_group_name = local.resource_group_name
}

data "kubernetes_service_account_v1" "deployer" {
  depends_on = [module.cluster]
  metadata {
    name      = "deployer"
    namespace = "default"
  }
}

data "kubernetes_secret" "deployer" {

  metadata {
    name      = data.kubernetes_service_account_v1.deployer.default_secret_name
    namespace = "default"
  }
}

output "deployer" {
  value = data.kubernetes_service_account_v1.deployer.default_secret_name
}

output "cluster_ca_certificate" {
  sensitive = true
  value     = base64encode(data.kubernetes_secret.deployer.data["ca.crt"])
}


output "kubernetes_url" {
  value = module.cluster.kubernetes_url
}

output "sa_username" {
  value = module.cluster.kubernetes_sa_username
}

output "sa_token" {
  value = module.cluster.kubernetes_sa_token
}

output "kubernetes_token" {
  value = module.cluster.kubernetes_token
}




resource "kubernetes_secret" "issuer-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "acme-azuredns"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
      "temporary.please.change/weaker-credentials-needed"       = true
    }
  }

  type = "Opaque"

  data = {
    "secret-access-key" = "foobar"
  }
}

#TODO: move to prereqs
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "harbor-pull-secret"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = "${base64decode(var.harbor_pull_secret_b64)}"
  }
}

resource "kubernetes_secret" "cod-snapshot-client-id" {
  depends_on = [
    module.cluster
  ]

  count = var.restore_snapshot_enabled == true ? 1 : 0

  metadata {
    name      = "cod-snapshot-client-id"
    namespace = "default"
  }

  data = {
    id = "${azuread_application.workload_identity.application_id}"
  }
}

data "azuread_client_config" "current" {}

resource "azuread_application" "workload_identity" {
  display_name = "${var.label}-${var.region}-workload-identity"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "workload_identity" {
  application_id               = azuread_application.workload_identity.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}


