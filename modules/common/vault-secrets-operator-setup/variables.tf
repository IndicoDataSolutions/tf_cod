variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}
variable "kubernetes_host" {}
variable "audience" {}
variable "environment" {}
locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}
