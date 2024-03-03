# General
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

variable "name" {
  type        = string
  default     = "indico"
  description = "Name to use in all cluster resources names (TODO: deprecate (redundant))"
}

variable "additional_tags" {
  type        = map(string)
  default     = null
  description = "Additonal tags to add to each resource"
}

variable "default_tags" {
  type        = map(string)
  default     = null
  description = "Default tags to add to each resource (redundant?)"
}

variable "dns_name" {
  type        = string
  default     = ".indico.io"
  description = "DNS name"
}

variable "domain_suffix" {
  type        = string
  default     = "indico.io"
  description = "Domain suffix"
}

variable "domain_host" {
  type        = string
  default     = ""
  description = "domain host name."
}

# Network
variable "direct_connect" {
  type        = bool
  default     = false
  description = "Sets up the direct connect configuration if true; else use public subnets"
}

variable "vpc_cidr" {
  type        = string
  description = "The VPC for the entire indico stack"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the private subnets"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the public subnets"
}

variable "subnet_az_zones" {
  type        = list(string)
  description = "Availability zones for the subnets"
}

# KMS
variable "existing_kms_key" {
  type        = string
  default     = ""
  description = "Name of kms key if it exists in the account (eg. 'alias/<name>')"
}

# SQS/SNS
variable "sqs_sns" {
  type        = bool
  default     = true
  description = "Flag for enabling SQS/SNS"
}

# Blob Storage
variable "submission_expiry" {
  type        = number
  description = "The number of days to retain submissions"
  default     = 30
}

variable "uploads_expiry" {
  type        = number
  description = "The number of days to retain uploads"
  default     = 30
}

variable "include_rox" {
  type        = bool
  default     = false
  description = "Create a read only FSx file system (TODO: remove (deprecated))"
}

variable "include_pgbackup" {
  type        = bool
  default     = true
  description = "Create a read only FSx file system"
}

# File Storage
variable "include_efs" {
  type        = bool
  default     = true
  description = "Create efs"
}

variable "include_fsx" {
  type        = bool
  default     = false
  description = "Create a fsx file system(s)"
}

variable "local_registry_enabled" {
  type    = bool
  default = false
}

variable "storage_capacity" {
  type        = number
  default     = 1200
  description = "Storage capacity in GiB for RWX FSx"
}

variable "per_unit_storage_throughput" {
  type        = number
  default     = 100
  description = "Throughput for each 1 TiB or storage (max 200) for RWX FSx"
}

# Cluster
variable "k8s_version" {
  type        = string
  default     = "1.27"
  description = "The EKS version to use"
}

variable "node_groups" {
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

variable "cluster_node_policies" {
  type        = list(any)
  default     = ["IAMReadOnlyAccess"]
  description = "Additonal IAM policies to add to the cluster IAM role"
}

variable "eks_cluster_iam_role" {
  type        = string
  default     = null
  description = "Name of the IAM role to assign to the EKS cluster; will be created if not supplied"
}

variable "snapshot_id" {
  type        = string
  default     = ""
  description = "The ebs snapshot of read-only data to use (TODO:?)"
}

variable "performance_bucket" {
  type        = bool
  default     = false
  description = "Add permission to connect to indico-locust-benchmark-test-results (TODO:?)"
}

# OIDC configuration (TODO: add other variables)
variable "oidc_enabled" {
  type        = bool
  default     = true
  description = "Enable OIDC Auhentication"
}

# WAF
variable "enable_waf" {
  type        = bool
  default     = false
  description = "enables aws alb controller for app-edge, also creates waf rules."
}

# Guardduty
variable "eks_addon_version_guardduty" {
  type        = bool
  default     = true
  description = "enable guardduty"
}

# DNS
variable "aws_primary_dns_role_arn" {
  type        = string
  default     = ""
  description = "The AWS arn for the role needed to manage route53 DNS in a different account."
}

variable "is_alternate_account_domain" {
  type        = string
  default     = "false"
  description = "domain name is controlled by a different aws account"
}

# Set up routes for monitoring
variable "monitoring_enabled" {
  type    = bool
  default = true
}
