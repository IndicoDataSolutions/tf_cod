
variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "region" {
  type        = string
  default     = "eastus"
  description = "The Azure region in which to launch the indico stack"
}

variable "account" {
  type        = string
  default     = "Azure-Dev"
  description = "The name of the subscription that this cluster falls under"
}

variable "domain_suffix" {
  type        = string
  default     = "indico.io"
  description = "Domain suffix"
}

variable "k8s_version" {
  type        = string
  default     = "1.23.12"
  description = "The version of the kubernetes cluster"
}

variable "github_organization" {
  default = "IndicoDataSolutions"
}

variable "ipa_smoketest_values" {
  type    = string
  default = "Cg==" # empty newline string
}

variable "ipa_smoketest_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "ipa_smoketest_container_tag" {
  type    = string
  default = "development-5cc16676"
}

variable "ipa_smoketest_version" {
  type    = string
  default = "0.2.1-add-openshift-crds-4a0b2155"
}

variable "ipa_smoketest_slack_channel" {
  type    = string
  default = "cod-smoketest-results"
}

variable "ipa_smoketest_enabled" {
  type    = bool
  default = true
}

variable "ipa_smoketest_cronjob_enabled" {
  type    = bool
  default = false
}

variable "ipa_smoketest_cronjob_schedule" {
  type    = string
  default = "0 0 * * *" # every night at midnight
}

variable "kubernetes_host" {
}
