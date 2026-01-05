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
variable "lambda_sns_forwarder_iam_principal_arn" {
  type        = string
  default     = ""
  description = "IAM principal ARN for the lambda SNS forwarder"
}

variable "account_id" {
  type        = string
  default     = ""
  description = "AWS account ID"
}

locals {
  account_region_name = lower("${var.account}-${var.region}-${var.name}")
}
