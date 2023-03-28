# foo

variable "use_admission_controller" { type = bool }
variable "ipa_namespace" {}
variable "ipa_repo" {}
variable "openshift_admission_chart_version" {}
variable "openshift_webhook_chart_version" {}
variable "crunchy_chart_version" {}

variable "resource_group_name" {}
variable "label" {}

variable "do_setup_openid_connect" { type = bool }
variable "openid_client_id" {}
variable "openid_connect_issuer_url" {}
variable "openid_client_secret" {}
variable "openid_groups_claim" {}
variable "openid_emailclaim" {}
variable "openid_preferred_username" {}
variable "openid_idp_name" {}

variable "openshift_console_url" {}
