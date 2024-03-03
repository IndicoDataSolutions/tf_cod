terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.0.1"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5.1"
    }
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.22.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "0.73.0"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "1.0.4"
    }
  }
}

provider "time" {}

provider "keycloak" {
  initial_login = false
}

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

provider "random" {}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
  default_tags {
    tags = var.default_tags
  }
}

provider "aws" {
  access_key = var.is_alternate_account_domain == "true" ? var.indico_aws_access_key_id : var.aws_access_key
  secret_key = var.is_alternate_account_domain == "true" ? var.indico_aws_secret_access_key : var.aws_secret_key
  region     = var.region
  alias      = "dns-control"
  default_tags {
    tags = var.default_tags
  }
}

provider "azurerm" {
  features {}
  alias           = "readapi"
  client_id       = var.azure_readapi_client_id
  client_secret   = var.azure_readapi_client_secret
  subscription_id = var.azure_readapi_subscription_id
  tenant_id       = var.azure_readapi_tenant_id
}

provider "azurerm" {
  features {}
  alias           = "indicoio"
  client_id       = var.azure_indico_io_client_id
  client_secret   = var.azure_indico_io_client_secret
  subscription_id = var.azure_indico_io_subscription_id
  tenant_id       = var.azure_indico_io_tenant_id
}

data "vault_kv_secret_v2" "terraform-snowflake" {
  mount = var.terraform_vault_mount_path
  name  = "snowflake"
}

provider "snowflake" {
  role        = "ACCOUNTADMIN"
  username    = var.snowflake_username
  account     = var.snowflake_account
  region      = var.snowflake_region
  private_key = jsondecode(data.vault_kv_secret_v2.terraform-snowflake.data_json)["snowflake_private_key"]
}

provider "htpasswd" {}

# argo
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host                   = module.infra.kube_host
  cluster_ca_certificate = base64decode(module.infra.kube_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = module.infra.kube_host
  cluster_ca_certificate = base64decode(module.infra.kube_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}

provider "helm" {
  debug = true
  kubernetes {
    host                   = module.infra.kube_host
    cluster_ca_certificate = base64decode(module.infra.kube_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.label]
      command     = "aws"
    }
  }
}


provider "aws" {
  access_key = var.indico_devops_aws_access_key_id
  secret_key = var.indico_devops_aws_secret_access_key
  region     = var.indico_devops_aws_region
  alias      = "aws-indico-devops"
}

data "aws_eks_cluster" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

data "aws_eks_cluster_auth" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

provider "kubectl" {
  alias                  = "thanos-kubectl"
  host                   = var.thanos_enabled == true ? data.aws_eks_cluster.thanos[0].endpoint : ""
  cluster_ca_certificate = var.thanos_enabled == true ? base64decode(data.aws_eks_cluster.thanos[0].certificate_authority[0].data) : ""
  token                  = var.thanos_enabled == true ? data.aws_eks_cluster_auth.thanos[0].token : ""
  load_config_file       = false
}
