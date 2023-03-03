variable "kubernetes_host" {
}
variable "kubernetes_client_certificate" {
}
variable "kubernetes_client_key" {
}
variable "kubernetes_cluster_ca_certificate" {
}
variable "argo_enabled" {
  type = bool
}

variable "argo_host" {
  type = string
}

variable "argo_username" {
  sensitive = true
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
}

variable "argo_github_team_owner" {
  description = "The GitHub Team that has owner-level access to this Argo Project"
  type        = string
}

variable "is_azure" {
  type    = bool
  default = true
}

variable "is_aws" {
  type    = bool
  default = false
}

variable "domain_suffix" {
  type        = string
  description = "Domain suffix"
}

variable "label" {
  type        = string
  description = "The unique string to be prepended to resources names"
}

variable "message" {
  type        = string
  description = "The commit message for updates"
}

variable "account" {
  type        = string
  description = "The name of the subscription that this cluster falls under"
}

variable "region" {
  type        = string
  description = "The Azure region in which to launch the indico stack"
}

variable "vnet_cidr" {
  type        = string
  description = "The VNet CIDR for the entire indico stack"
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the subnet(s)"
}

variable "worker_subnet_cidrs" {
  type        = list(string)
  description = "CIDR range for the worker database subnet"
}

### cluster manager variables
variable "cluster_manager_vm_size" {
  type        = string
  default     = "Standard_Fs_v2"
  description = "The cluster manager instance size"
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

  default = {
    name                           = "empty"
    cluster_auto_scaling           = false
    cluster_auto_scaling_max_count = 0
    cluster_auto_scaling_min_count = 0
    labels = {
      "key" = "value"
    }
    node_count = 0
    node_os    = "value"
    pool_name  = "value"
    taints     = ["value"]
    vm_size    = "value"
    zones      = ["value"]
  }
}

variable "additional_node_pools" {
  type = map(object({
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    pool_name                      = string
    taints                         = list(string)
    labels                         = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
  }))

  default = {
    "empty" = {
      cluster_auto_scaling           = false
      cluster_auto_scaling_max_count = 0
      cluster_auto_scaling_min_count = 0
      labels = {
        "key" = "value"
      }
      node_count = 1
      node_os    = "value"
      pool_name  = "value"
      taints     = ["value"]
      vm_size    = "value"
      zones      = ["value"]
    }
  }
}

variable "harbor_pull_secret_b64" {
  sensitive   = true
  type        = string
  description = "Harbor pull secret from Vault"
}

variable "admin_group_name" {
  type        = string
  description = "Name of group that will own the cluster"
}

variable "enable_k8s_dashboard" {
  type    = bool
  default = true
}

variable "name" {
  type        = string
  description = "Name to use in all cluster resources names"
}

variable "vault_mount_path" {
  type = string
}

variable "vault_mount" {
}

variable "ad_group_name" {
  description = "Name of an AD group to be mapped if enable_ad_group_mapping is true"
}

variable "enable_ad_group_mapping" {
  type        = bool
  description = "Enable the Mapping of AD Group"
}

#openshift & azure common variables

# enable for openshift
variable "is_openshift" {
  type    = bool
  default = false
}

variable "openshift_pull_secret" {
  type = string
}

variable "openshift_machine_sets" {
  type = map(object({
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    pool_name                      = string
    taints                         = list(string)
    labels                         = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
    storageAccountType             = string
    image = object({
      offer      = string
      publisher  = string
      resourceID = string
      sku        = string
      version    = string
    })
  }))
}

variable "roles" {
  description = "Roles to be assigned to the Principal"
  type        = list(object({ role = string }))
  default = [
    {
      role = "Contributor"
    },
    {
      role = "User Access Administrator"
    }
  ]
}
variable "ipa_openshift_crds_version" {
  type = string
}

variable "openshift_version" {
}


variable "ipa_repo" {
  type = string
}


