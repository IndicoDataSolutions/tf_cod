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

variable "helm_registry" {
  type        = string
  description = "Registry for the helm charts"
}

variable "namespace" {
  type        = string
  description = "Namespace for the indico charts"
}

variable "account_name" {
  type        = string
  description = "Account name for the vault path"
}

variable "label" {
  type        = string
  description = "name of the cluster"
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

variable "insights_enabled" {
  type        = bool
  description = "Toggle for enabling insights"
}


