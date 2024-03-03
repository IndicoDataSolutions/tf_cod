variable "aws_account" {
  type        = string
  description = "The Name of the AWS Acccount this cluster lives in"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region in which to launch the indico stack"
}

variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

# Install
variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "monitoring_version" {
  type    = string
  default = "0.3.3"
}

variable "keda_version" {
  default = "2.11.2"
}

variable "opentelemetry-collector_version" {
  default = "0.30.0"
}

# Thanos
variable "thanos_enabled" {
  type    = bool
  default = true
}

variable "argo_enabled" {
  type    = bool
  default = true
}

variable "vault_address" {
  type    = string
  default = "https://vault.devops.indico.io"
}

# Alerting
variable "alerting_enabled" {
  type        = bool
  default     = false
  description = "enable alerts"
}

variable "alerting_slack_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via slack"
}

variable "alerting_pagerduty_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via pagerduty"
}

variable "alerting_email_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via email"
}

variable "alerting_slack_token" {
  type        = string
  default     = "blank"
  description = "Secret url with embedded token needed for slack webhook delivery."
}

variable "alerting_slack_channel" {
  type        = string
  default     = "blank"
  description = "Slack channel for sending notifications from alertmanager."
}

variable "alerting_pagerduty_integration_key" {
  type        = string
  default     = "blank"
  description = "Secret pagerduty_integration_key."
}

variable "alerting_email_from" {
  type        = string
  default     = "blank"
  description = "alerting_email_from."
}

variable "alerting_email_to" {
  type        = string
  default     = "blank"
  description = "alerting_email_to"
}

variable "alerting_email_host" {
  type        = string
  default     = "blank"
  description = "alerting_email_host"
}

variable "alerting_email_username" {
  type        = string
  default     = "blank"
  description = "alerting_email_username"
}

variable "alerting_email_password" {
  type        = string
  default     = "blank"
  description = "alerting_email_password"
}

# Static SSL
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

# DNS
variable "dns_name" {
  type        = string
  description = "dns name for the cluster"
}

