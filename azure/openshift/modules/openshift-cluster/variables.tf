variable "resource_group_name" {
  type        = string
  description = "Resource group name that this cluster will be placed in"
}

variable "label" {
  type        = string
  description = "Name of this Openshift Cluster"
}

variable "cluster_domain" {
  type        = string
  description = "Domain Openshift Cluster"
}
variable "pull_secret" {
  type        = string
  description = "Redhat Pull Secret"
}

variable "tags" {
  default = {}
}

variable "region" {
  type        = string
  description = "Region for this Cluster"
}

variable "master_subnet_id" {
  type        = string
  description = "Subnet ID for Master Network"
}

variable "worker_subnet_id" {
  type        = string
  description = "Subnet ID for Worker Network"
}

variable "svp_client_id" {
  type        = string
  sensitive   = true
  description = "Service Principal Client ID"
}

variable "svp_client_secret" {
  type        = string
  sensitive   = true
  description = "Service Principal Client Secret"
}

variable "enable_oidc_issuer" {
  type        = bool
  default     = false
  description = "Enable OIDC Issuer URL"
}


