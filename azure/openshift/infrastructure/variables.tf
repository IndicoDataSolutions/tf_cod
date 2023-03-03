# top level variable declarations
variable "common_resource_group" {}
variable "resource_group_name" {}
variable "label" {}
variable "region" {}
variable "base_domain" {}
variable "dns_name" {}
variable "dns_prefix" {}
variable "enable_dns_infrastructure" { type = bool }
variable "enable_gpu_infrastructure" { type = bool }
variable "enable_monitoring_infrastructure" { type = bool }

variable "restore_snapshot_enabled" { type = bool }
variable "use_workload_identity" { type = bool }
variable "cluster_oidc_issuer_url" {}
variable "kubelet_identity_client_id" {}
vairable "harbor_pull_secret_b64" {}

variable "ipa_namespace" {}
variable "ipa_repo" {}
variable "ipa_crds_version" {}
variable "storage_account_name" {}
variable "storage_account_primary_access_key" {}
variable "blob_store_name" {}



variable "nvidia_operator_namespace" {}
variable "nfd_namespace" {}
variable "ipa_openshift_crds_version" {}
variable "ipa_repo" {}
variable "monitoring_version" {}
variable "opentelemetry-collector_version" {}
variable "keda_version" {}


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

