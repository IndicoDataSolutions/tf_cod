# locals.dns_name
variable "local_dns_name" {}

variable "k8s_dashboard_chart_version" {
  default = "0.3.2-main-c20c783e"
}

variable "ipa_repo" {}

variable "keycloak_client_id" {

}

variable "keycloak_client_secret" {

}

variable "use_static_ssl_certificates" {
  type        = bool
  default     = false
  description = "use static ssl certificates for clusters which cannot use certmanager and external dns."
}

variable "ssl_static_secret_name" {
  type        = string
  default     = "indico-ssl-static-cert"
  description = "secret_name for static ssl certificate"
}

variable "image_registry" {
  type        = string
  default     = "harbor.devops.indico.io"
  description = "docker image registry to use for pulling images."
}
