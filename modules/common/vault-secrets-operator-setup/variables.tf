variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}

locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}
