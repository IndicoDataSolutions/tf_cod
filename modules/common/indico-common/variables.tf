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

variable "indico_crds_values_yaml_b64" {
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

variable "indico_pre_reqs_values_yaml_b64" {
  type        = string
  default     = "Cg=="
  description = "indico-pre-requisistes values provided by the user in the cod.yaml"
}

variable "indico_pre_reqs_values_overrides" {
  type        = list(string)
  default     = []
  description = "indico-pre-requisites values overrides from the terraform"
}

variable "indico_core_version" {
  type        = string
  default     = ""
  description = "Version of the indico-core helm chart"
}

variable "indico_core_values" {
  type        = list(string)
  default     = []
  description = "indico-core values overrides from the terraform"
}

variable "monitoring_enabled" {
  type        = bool
  default     = true
  description = "Flag to enable/disable monitoring"
}

variable "monitoring_values" {
  type        = list(string)
  default     = []
  description = "Monitoring values"
}

variable "monitoring_version" {
  type        = string
  default     = ""
  description = "Monitoring chart version"
}

variable "load_environment" {
  type        = string
  default     = ""
  description = "Environment to load the service mesh from"
}

variable "enable_service_mesh" {
  type        = bool
  default     = true
  description = "Toggle for enabling service mesh deployment"
}

variable "service_mesh_namespace" {
  type        = string
  default     = "linkerd"
  description = "Namespace for the service mesh"
}

variable "linkerd_crds_version" {
  type        = string
  description = "Version for the linkerd crds"
}

variable "linkerd_control_plane_version" {
  type        = string
  description = "Version for the linkerd control plane"
}

variable "linkerd_viz_version" {
  type        = string
  description = "Version for the linkerd viz"
}


variable "linkerd_multicluster_version" {
  type        = string
  description = "Version for the linkerd multicluster"
}

variable "account_name" {
  type        = string
  description = "Account name for the vault path"
}

variable "label" {
  type        = string
  description = "name of the cluster"
}

variable "region" {
  type        = string
  description = "Region of the cluster"
}

variable "image_registry" {
  type        = string
  description = "Image registry"
}

variable "linkerd_crds_values" {
  type        = list(string)
  default     = []
  description = "Values for the linkerd crds"
}

variable "linkerd_control_plane_values" {
  type        = list(string)
  default     = []
  description = "Values for the linkerd control plane"
}

variable "linkerd_viz_values" {
  type        = list(string)
  default     = []
  description = "Values for the linkerd viz"
}

variable "linkerd_multicluster_values" {
  type        = list(string)
  default     = []
}

variable "trust_manager_version" {
  type        = string
  description = "Version for the trust manager"
}

variable "trust_manager_values" {
  type        = list(string)
  default     = []
  description = "Values for the trust manager"
}

variable "insights_enabled" {
  type        = bool
  description = "Toggle for enabling insights"
}

variable "environment" {
  type        = string
  description = "Environment for the service mesh"
}

variable "use_local_helm_charts" {
  type        = bool
  default     = false
  description = "Toggle for using local helm charts"
}