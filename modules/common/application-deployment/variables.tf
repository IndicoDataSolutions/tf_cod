variable "account" {
  type        = string
  default     = ""
  description = ""
}

variable "region" {
  type        = string
  default     = ""
  description = ""
}

variable "label" {
  type        = string
  default     = ""
  description = ""
}

variable "namespace" {
  type        = string
  default     = ""
  description = ""
}

variable "argo_enabled" {
  type        = bool
  default     = true
  description = "Flag to enable/disable argo. If argo is diabled, everything will be installed through helm"
}

# Argo enabled
variable "github_repo_name" {
  type        = string
  default     = ""
  description = ""
}

variable "github_repo_branch" {
  type        = string
  default     = ""
  description = ""
}

variable "github_file_path" {
  type        = string
  default     = ""
  description = ""
}

variable "github_commit_message" {
  type        = string
  default     = ""
  description = ""
}

variable "argo_application_name" {
  type        = string
  default     = ""
  description = ""
}

variable "argo_vault_plugin_path" {
  type        = string
  default     = ""
  description = ""
}

variable "argo_server" {
  type        = string
  default     = ""
  description = ""
}

variable "argo_project_name" {
  type        = string
  default     = ""
  description = ""
}

# Argo disabled, use helm
variable "chart_name" {
  type        = string
  default     = ""
  description = ""
}

variable "chart_repo" {
  type        = string
  default     = ""
  description = ""
}

variable "chart_version" {
  type        = string
  default     = ""
  description = ""
}

variable "k8s_version" {
  type        = string
  default     = ""
  description = ""
}

variable "release_name" {
  type        = string
  default     = ""
  description = ""
}

variable "terraform_helm_values" {
  type        = string
  default     = ""
  description = ""
}

variable "helm_values" {
  type        = string
  default     = ""
  description = ""
}

