variable "harbor_pull_secret_b64" {
  sensitive   = true
  type        = string
  description = "Harbor pull secret from Vault"
}

variable "vault_mount_path" {
  type    = string
  default = "terraform"
}

# GitHub repo vars
variable "argo_enabled" {
  type    = bool
  default = true
}

variable "argo_branch" {
  description = "Branch to use on argo_repo"
  default     = ""
}

variable "argo_path" {
  description = "Path within the argo_repo containing yaml"
  default     = "."
}

variable "message" {
  type        = string
  default     = "Managed by Terraform"
  description = "The commit message for updates"
}

# Helm variables
variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "infra_crds_version" {
  type    = string
  default = "0.2.1"
}

variable "crds-values-yaml-b64" {
  default = "Cg=="
}

