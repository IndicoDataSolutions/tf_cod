variable "argo_enabled" {
  type        = bool
  default     = true
  description = "Flag to enable/disable argo. If argo is diabled, everything will be installed through helm"
}

# Argo enabled
variable "github_repo_name" {
  type        = string
  default     = ""
  description = "Repo where the cod.yaml, application.yaml, and helm overrides are stored when argo is enabled"
}

variable "github_repo_branch" {
  type        = string
  default     = ""
  description = "Branch of the repo"
}

variable "github_file_path" {
  type        = string
  default     = "."
  description = "Path of the yaml files in the repo"
}

variable "github_commit_message" {
  type        = string
  default     = ""
  description = "Commit message to send to github when adding application configuration files"
}

variable "helm_registry" {
  type        = string
  default     = "https://harbor.devops.indico.io/chartrepo/indico-charts"
  description = "Helm registry URL"
}

variable "namespace" {
  type        = string
  default     = "indico"
  description = "Namespace to deploy indico common deployments/secrets"
}

# CRDS helm install
variable "indico_crds_version" {
  type        = string
  default     = ""
  description = "indico-crds chart version to deploy to the cluster"
}

variable "crds_values_yaml_b64" {
  type        = string
  default     = "Cg=="
  description = "indico-crds values provided by the user in the cod.yaml"
}

variable "indico_crds_values_overrides" {
  type        = list(string)
  default     = []
  description = "indico-crds values overrides from the terraform"
}

# indico-pre-requisites install 
variable "indico_pre_reqs_version" {
  type        = string
  default     = ""
  description = "indico-pre-requisistes chart version to deploy to the cluster"
}

variable "pre_reqs_values_yaml_b64" {
  type        = string
  default     = "Cg=="
  description = "indico-pre-requisistes values provided by the user in the cod.yaml"
}

variable "indico_pre_reqs_values_overrides" {
  type        = list(string)
  default     = []
  description = "indico-pre-requisites values overrides from the terraform"
}

variable "github_token" {
  type        = string
  default     = ""
  description = "Github token to use for the github provider"
}
