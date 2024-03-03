# Cluster info
variable "aws_account" {
  type        = string
  description = "The Name of the AWS Acccount this cluster lives in"
}

# Helm variables
variable "argo_enabled" {
  type    = bool
  default = true
}

variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "local_registry_version" {
  type    = string
  default = "unused"
}

variable "dns_name" {
  type        = string
  description = "dns name for the cluster"
}

variable "efs_filesystem_id" {
  type        = string
  description = "id for local-registry efs filesystem"
}

variable "htpasswd_bcrypt" {
  description = "Generated htpasswd"
  sensitive   = true
}

variable "general_password" {
  description = "Generated general password"
  sensitive   = true
}
