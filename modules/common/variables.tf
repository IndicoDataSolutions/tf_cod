# locals.dns_name
variable "local_dns_name" {}

variable "k8s_dashboard_chart_version" {
  default = "0.1.0"
}

variable "enable_k8s_dashboard" {
  type    = bool
  default = true
}

variable "ipa_repo" {}

