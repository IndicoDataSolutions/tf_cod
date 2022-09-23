terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.23.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.2.3"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "http" {}

provider "time" {}

provider "vault" {
  address          = var.vault_address
  skip_child_token = true
  auth_login {
    method = "github"
    path   = "auth/github/login"
    parameters = {
      token = var.git_pat
    }
  }
}

data "http" "workstation-external-ip" {
  url = "http://ipv4.icanhazip.com"
}


provider "github" {
  token = var.git_pat
  owner = "IndicoDataSolutions"
}

provider "local" {}

locals {
  resource_group_name = "${var.label}-${var.region}"
  current_ip = "${chomp(data.http.workstation-external-ip.body)}"
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_resource_group" "cod-cluster" {
  name     = local.resource_group_name
  location = var.region
}

module "networking" {
  source               = "app.terraform.io/indico/indico-azure-network/mod"
  version              = "2.0.1"
  label                = var.label
  app_subnet_name      = "${var.label}-subnet" # remove me
  vnet_cidr            = var.vnet_cidr
  subnet_cidrs         = var.subnet_cidrs
  database_subnet_cidr = var.database_subnet_cidr
  resource_group_name  = var.resource_group_name
}

/*
module "asq_eventgrid" {
  count = var.asq_eventgrid == true ? 0 : 1
  source  = "app.terraform.io/indico/indico-azure-aqs-eventgrid/mod"
  version = "1.0.0"
  region  = var.region
  label   = var.label
}
*/

module "cluster-manager" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source              = "app.terraform.io/indico/indico-azure-cluster-manager/mod"
  version             = "2.0.7"
  label               = var.label
  subnet_id           = module.networking.subnet_id
  public_key          = tls_private_key.pk.public_key_openssh
  region              = var.region
  vm_size             = var.cluster_manager_vm_size
  external_ip         = var.external_ip
  resource_group_name = local.resource_group_name
}

/*
module "key_vault_key" {
  source          = "app.terraform.io/indico/indico-aws-kms/mod"
  version         = "1.1.0"
  label           = var.label
  additional_tags = var.additional_tags
}*/

module "blob-storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source               = "app.terraform.io/indico/indico-azure-blob/mod"
  version              = "0.0.13"
  label                = var.label
  region               = var.region
  current_ip           = local.current_ip
  external_ip          = var.external_ip
  subnet_id            = module.networking.subnet_id
  resource_group_name  = local.resource_group_name
}

/*
module "security-group" {
  source   = "app.terraform.io/indico/indico-aws-security-group/mod"
  version  = "1.0.0"
  label    = var.label
  vpc_cidr = var.vpc_cidr
  vpc_id   = local.network[0].indico_vpc_id
}*/

module "file-storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source               = "app.terraform.io/indico/indico-azure-file-shares/mod"
  version              = "2.0.1"
  label                = "${var.label}-dcm"
  region               = var.region
  storage_account_name = "${var.label}file"
  vnet_cidr            = var.vnet_cidr
  current_ip           = local.current_ip
  external_ip          = var.external_ip
  subnet_id            = module.networking.subnet_id
  resource_group_name  = local.resource_group_name
}

module "cluster" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source                  = "app.terraform.io/indico/indico-azure-cluster/mod"
  version                 = "2.0.7"
  label                   = var.label
  public_key              = tls_private_key.pk.public_key_openssh
  region                  = var.region
  svp_client_id           = var.svp_client_id
  svp_client_secret       = var.svp_client_secret
  default_node_pool       = var.default_node_pool
  additional_node_pools   = var.additional_node_pools
  vnet_subnet_id          = module.networking.subnet_id
  k8s_version             = var.k8s_version
  private_cluster_enabled = var.private_cluster_enabled
  resource_group_name     = local.resource_group_name
}