variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}
variable "kubernetes_host" {}
variable "audience" {
  default = "vault"
}
variable "vault_username" {}
variable "vault_password" {}

locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}
