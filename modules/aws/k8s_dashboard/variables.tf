# locals.dns_name
variable "local_dns_name" {}

variable "k8s_dashboard_chart_version" {
  default = "0.1.1-dns-resolver-3ef71e2e"
}

variable "ipa_repo" {}

variable "keycloak_client_id" {

}

variable "keycloak_client_secret" {

}
