# Cluster metadata
variable "dns_name" {
  type        = string
  default     = ".indico.io"
  description = "DNS name"
}

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

# DNS
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

# Helm
variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "argo_enabled" {
  type    = bool
  default = true
}

variable "argo_repo" {
  description = "Argo Github Repository containing the IPA Application"
  default     = ""
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

variable "ipa_pre_reqs_version" {
  type    = string
  default = "0.4.0"
}

variable "pre-reqs-values-yaml-b64" {
  default = "Cg=="
}

variable "ipa_version" {
  type    = string
  default = "0.12.1"
}

variable "ipa_values" {
  type    = string
  default = ""
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of availability zones for nodes"

  validation {
    condition     = var.az_count > 0 && var.az_count <= 3
    error_message = "The az_count must be in the range 1-3"
  }
}

variable "key_arn" {
  type        = string
  description = ""
}

variable "s3_role_id" {
  type        = string
  description = ""
}

variable "pgbackup_s3_bucket_name" {
  type        = string
  description = ""
}

variable "use_acm" {
  type        = bool
  default     = false
  description = "create cluster that will use acm"
}

variable "kubernetes_host" {
  type        = string
  description = ""
}

variable "indico_vpc_id" {
  type        = string
  description = ""
}

variable "public_subnet_ids" {
  description = "Public subnet ids of the cluster"
  default     = []
}

variable "argo_project_name" {
  type        = string
  description = ""
}

variable "k8s_version" {
  type        = string
  default     = "1.27"
  description = "The EKS version to use"
}

variable "local_registry_enabled" {
  type    = bool
  default = false
}

variable "on_prem_test" {
  type    = bool
  default = false
}

variable "enable_waf" {
  type        = bool
  default     = false
  description = "enables aws alb controller for app-edge, also creates waf rules."
}

variable "waf_arn" {
  type        = string
  description = "waf acl web arn"
  default     = ""
}

variable "acm_arn" {
  type        = string
  description = "acm cert validation arn"
  default     = ""
}

variable "include_efs" {
  type        = bool
  default     = true
  description = "Create efs"
}

variable "efs_filesystem_id" {
  type        = string
  description = "EFS filesystem id"
  default     = ""
}

variable "include_fsx" {
  type        = bool
  default     = false
  description = "Create a fsx file system(s)"
}

variable "fsx_rwx" {
  description = "fsx_rwx object from infra module output"
  default     = {}
}

variable "monitoring_password" {
  type        = string
  description = "Generated password for monitoring"
  sensitive   = true
  default     = ""
}

# Smoketest
variable "ipa_smoketest_values" {
  type    = string
  default = "Cg==" # empty newline string
}

variable "ipa_smoketest_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "ipa_smoketest_version" {
  type    = string
  default = "0.1.8"
}

variable "ipa_smoketest_enabled" {
  type    = bool
  default = true
}

# Snapshot 
variable "restore_snapshot_enabled" {
  default     = false
  type        = bool
  description = "Flag for restoring cluster from snapshot"
}

variable "restore_snapshot_name" {
  type        = string
  default     = ""
  description = "Name of snapshot in account's s3 bucket"
}
