
variable "label" {
  type        = string
  description = "The unique string to be prepended to resources names"
}

variable "region" {
  type        = string
  description = "The Azure region in which to launch the indico stack"
}

variable "account" {
  type        = string
  description = "The name of the subscription that this cluster falls under"
}

variable "domain_suffix" {
  type        = string
  description = "Domain suffix"
}

variable "k8s_version" {
  type        = string
  description = "The version of the kubernetes cluster"
}

variable "github_organization" {
}

variable "ipa_smoketest_values" {
  type = string
}

variable "ipa_smoketest_repo" {
  type = string
}

variable "ipa_smoketest_container_tag" {
  type = string
}

variable "ipa_smoketest_version" {
  type = string
}

variable "ipa_smoketest_slack_channel" {
  type = string
}

variable "ipa_smoketest_enabled" {
  type = bool
}

variable "ipa_smoketest_cronjob_enabled" {
  type = bool
}

variable "ipa_smoketest_cronjob_schedule" {
  type = string
}

variable "kubernetes_host" {
}

variable "argo_repo" {}
variable "argo_branch" {}
variable "argo_path" {}



variable "argo_enabled" { type = bool }
variable "monitoring_namespace" {}
variable "message" {}
