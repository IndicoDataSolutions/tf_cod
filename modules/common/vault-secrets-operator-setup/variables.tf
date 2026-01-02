variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}
variable "kubernetes_host" {}
variable "audience" {}
variable "environment" {}
variable "vault_username" {}
variable "vault_password" {}

variable "lambda_sns_forwarder_enabled" {
  type    = bool
  default = false
}
variable "lambda_sns_forwarder_iam_principal_arn" {}

variable "account_id" {}

locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}
