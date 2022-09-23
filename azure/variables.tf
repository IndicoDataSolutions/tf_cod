# top level variable declarations
variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "resource_group_name" {
  type        = string
  default     = "indico-data"
  description = "The name of the resource group to which all indico components will belong"
}

variable "region" {
  type        = string
  default     = "eastus"
  description = "The Azure region in which to launch the indico stack"
}

variable "external_ip" {
  type        = string
  default     = "35.174.218.89"
  description = "The external IP which is allowed to connect to the cluster through ssh"
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
  default     = "1.23.10"
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
