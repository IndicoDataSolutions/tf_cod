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
  default     = ""
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
  default     = "default"
  description = "Namespace to deploy intake deployments/secrets. Defaults to 'default' due to historical placement"
}

# pre reqs buttons
variable "ins_pre_reqs_version" {
  type        = string
  default     = ""
  description = "ipa-pre-requisistes chart version to deploy to the cluster"
}

variable "pre_reqs_values_yaml_b64" {
  type        = string
  default     = "Cg=="
  description = "ipa-pre-requisistes values provided by the user in the cod.yaml"
}

variable "ins_pre_reqs_values_overrides" {
  type        = list(string)
  default     = []
  description = "ipa-pre-requisites values overrides from the terraform"
}

# Application deployment
variable "account" {
  type        = string
  default     = ""
  description = "Account name for the cluster"
}

variable "region" {
  type        = string
  default     = ""
  description = "Region of the cluster"
}

variable "label" {
  type        = string
  default     = ""
  description = "Name of the cluster"
}

variable "argo_application_name" {
  type        = string
  default     = ""
  description = "Name of the application to create in Argo for intake"
}

variable "vault_path" {
  type        = string
  default     = ""
  description = "Vault path for secrets in the application (generally not used)"
}

variable "argo_server" {
  type        = string
  default     = ""
  description = "Server to deploy the Argo application to"
}

variable "argo_project_name" {
  type        = string
  default     = ""
  description = "Argo project the application falls under"
}

variable "insights_version" {
  type        = string
  default     = ""
  description = "Helm chart version of the intake helm chart"
}

variable "k8s_version" {
  type        = string
  default     = ""
  description = "The kubernetes version of the cluster"
}

variable "insights_values_terraform_overrides" {
  type        = string
  default     = ""
  description = "Overrides to the helm values of the intake chart from tf_cod"
}

variable "insights_values_overrides" {
  type        = string
  default     = ""
  description = "Overrides to the helm values of the intake chart from the cod user"
}

variable "use_local_helm_charts" {
  type        = bool
  default     = false
  description = "Toggle for using local helm charts"
}

variable "install_local_insights_chart" {
  type        = bool
  default     = false
  description = "Toggle for installing the local insights chart"
}