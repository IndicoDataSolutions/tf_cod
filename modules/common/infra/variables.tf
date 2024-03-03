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

variable "argo_repo" {
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

variable "dns_name" {
  type        = string
  default     = ".indico.io"
  description = "DNS name"
}

variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "infra_crds_version" {
  type    = string
  default = "0.2.1"
}

variable "infra-crds-values-yaml-b64" {
  default = "Cg=="
}

variable "infra_pre_reqs_version" {
  type    = string
  default = "0.2.1"
}

variable "infra-pre-reqs-values-yaml-b64" {
  default = "Cg=="
}

variable "include_efs" {
  type        = bool
  default     = true
  description = "Create efs"
}

variable "efs_filesystem_id" {
  type        = string
  default     = ""
  description = "EFS id if EFS is enabled"
}

variable "include_fsx" {
  type        = bool
  default     = false
  description = "Create a fsx file system(s)"
}

variable "security_group_id" {
  type        = string
  default     = ""
  description = "FSX security group id if FSX is enabled"
}

variable "fsx_rwx_subnet_id" {
  type        = string
  default     = ""
  description = "FSX subnet id if FSX is enabled"
}

variable "local_registry_enabled" {
  type    = bool
  default = false
}

variable "use_static_ssl_certificates" {
  type        = bool
  default     = false
  description = "use static ssl certificates for clusters which cannot use certmanager and external dns."
}

variable "is_alternate_account_domain" {
  type        = string
  default     = "false"
  description = "domain name is controlled by a different aws account"
}

variable "aws_primary_dns_role_arn" {
  type        = string
  default     = ""
  description = "The AWS arn for the role needed to manage route53 DNS in a different account."
}



