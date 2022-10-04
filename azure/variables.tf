# top level variable declarations
variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "region" {
  type        = string
  default     = "eastus"
  description = "The Azure region in which to launch the indico stack"
}

variable "external_ip" {
  type        = string
  default     = "35.174.218.89"
  description = "The external IP which is allowed to connect to the cluster through ssh (AWS SSO VPN)"
}

variable "vnet_cidr" {
  type        = string
  description = "The VNet CIDR for the entire indico stack"
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the subnet(s)"
}

variable "database_subnet_cidr" {
  type        = list(string)
  default     = null
  description = "CIDR range for the delegated database subnet"
}

### storage account variables
variable "storage_account_name" {
  type        = string
  default     = "indicodatatest"
  description = "Name of the indico storage account"
}

variable "argo_host" {
  type    = string
  default = "argo.devops.indico.io"
}

variable "argo_username" {
  sensitive = true
  default   = "admin"
}

variable "argo_password" {
  sensitive = true
}

variable "argo_repo" {
  description = "Argo Github Repository containing the IPA Application"
}

variable "argo_branch" {
  description = "Branch to use on argo_repo"
}

variable "argo_path" {
  description = "Path within the argo_repo containing yaml"
  default     = "."
}

variable "argo_github_team_owner" {
  description = "The GitHub Team that has owner-level access to this Argo Project"
  type        = string
  default     = "devops-core-admins" # any group other than devops-core
}

variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts-dev"
}

variable "ipa_version" {
  type    = string
  default = "0.1.2"
}

variable "monitoring_version" {
  type    = string
  default = "0.0.1"
}

variable "ipa_pre_reqs_version" {
  type    = string
  default = "0.1.1"
}

variable "ipa_crds_version" {
  type    = string
  default = "0.1.0"
}

variable "ipa_enabled" {
  type    = bool
  default = true
}

variable "ipa_values" {
  type    = string
  default = ""
}

variable "git_pat" {
  type      = string
  sensitive = true
  default   = ""
}

### cluster manager variables
variable "cluster_manager_vm_size" {
  type        = string
  default     = "Standard_Fs_v2"
  description = "The cluster manager instance size"
}

### cluster variables
variable "private_cluster_enabled" {
  type        = bool
  default     = false
  description = "If enabled, the cluster will be launched as a private cluster"
}

variable "svp_client_id" {
  type        = string
  description = "The client ID of the service principal to use"
}

variable "svp_client_secret" {
  type        = string
  description = "The password of the service principal to use"
}

variable "k8s_version" {
  type        = string
  default     = "1.24.3"
  description = "The version of the kubernetes cluster"
}

variable "default_node_pool" {
  type = object({
    node_count                     = number
    vm_size                        = string
    name                           = string
    zones                          = list(string)
    taints                         = list(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
  })
}

variable "additional_node_pools" {
  type = map(object({
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    pool_name                      = string
    taints                         = list(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
  }))
}
