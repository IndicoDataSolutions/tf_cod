terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.23.0"
    }
  }
}

provider "azurerm" {
  features {}
}

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

provider "github" {
  token = var.git_pat
  owner = "IndicoDataSolutions"
}

provider "random" {}

locals {
  resource_group_name = "${var.label}-${var.region}"
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
  source              = "app.terraform.io/indico/indico-azure-cluster-manager/mod"
  version             = "1.0.0"
  label               = var.label
  subnet_id           = module.networking.subnet_id
  public_key_path     = var.public_key_path
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
  source               = "app.terraform.io/indico/indico-azure-blob/mod"
  version              = "0.0.8"
  label                = var.label
  region               = var.region
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
  source               = "app.terraform.io/indico/indico-azure-file-shares/mod"
  version              = "1.0.0"
  label                = "${var.label}-dcm"
  region               = var.region
  storage_account_name = var.storage_account_name
  vnet_cidr            = var.vnet_cidr
  external_ip          = var.external_ip
  subnet_id            = module.networking.subnet_id
  resource_group_name  = local.resource_group_name
}

module "cluster" {
  source                  = "app.terraform.io/indico/indico-azure-cluster/mod"
  version                 = "1.1.0"
  label                   = var.label
  public_key_path         = var.public_key_path
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