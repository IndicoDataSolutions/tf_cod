# top level variable declarations
variable "common_resource_group" {}
variable "resource_group_name" {}
variable "label" {}
variable "region" {}
variable "base_domain" {}
variable "dns_prefix" {}
variable "enable_dns_infrastructure" { type = bool }
variable "enable_gpu_infrastructure" { type = bool }
variable "enable_monitoring_infrastructure" { type = bool }
variable "nvidia_operator_namespace" {}
