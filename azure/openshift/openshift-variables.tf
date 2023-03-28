

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


variable "use_private_console" {
  type    = bool
  default = false
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
  type    = string
  default = "0.1.1-IPA-6.1.0.rc-4e17ac41"
}

variable "openshift_version" {
  default = "4.10.40"
}

variable "vault_mount" {
  default = "terraform"
}

variable "nvidia_operator_namespace" {
  default = "nvidia-gpu-operator"
}


# openid connect
variable "do_setup_openid_connect" {
  type    = bool
  default = false
}

variable "openid_connect_issuer_url" { default = "" }
variable "openid_client_secret" { default = "" }
variable "openid_groups_claim" { default = "" }
variable "openid_emailclaim" { default = "" }
variable "openid_preferred_username" { default = "" }
variable "openid_idp_name" { default = "keycloak" }
variable "openid_client_id" { default = "" }


variable "openshift_console_url" {
  default = ""
}
