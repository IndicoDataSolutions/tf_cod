variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "node_role_name" {
  type = string
}

variable "k8s_version" {
  type = string
}

variable "az_count" {
  type        = number
  default     = 2
  description = "The number of azs to use in the cluster, range 1-3"

  validation {
    condition     = var.az_count > 0 && var.az_count <= 3
    error_message = "The az_count must be in the range 1-3"
  }
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}

variable "helm_registry" {
  type = string
}

variable "karpenter_version" {
  type = string
}

variable "default_tags" {
  type    = map(string)
  default = null
}

variable "instance_volume_size" {
  type = number
}

variable "instance_volume_type" {
  type = string
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "node_pools" {
  default = null
}
