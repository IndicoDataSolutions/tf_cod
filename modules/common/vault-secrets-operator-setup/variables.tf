variable "vault_address" {}

variable "account" {}
variable "region" {}
variable "name" {}
variable "kubernetes_host" {}
variable "audience" {
  default = "vault"
}

variable "external_secrets_version" {}
