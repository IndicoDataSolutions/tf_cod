#
variable "is_azure" {
  type    = bool
  default = true
}

variable "is_aws" {
  type    = bool
  default = false
}

# top level variable declarations
variable "common_resource_group" {
  type        = string
  default     = "indico-common"
  description = "The common resource group name"
}

variable "domain_suffix" {
  type        = string
  default     = "indico.io"
  description = "Domain suffix"
}

variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "message" {
  type        = string
  default     = "Managed by Terraform"
  description = "The commit message for updates"
}

variable "account" {
  type        = string
  default     = "Azure-Dev"
  description = "The name of the subscription that this cluster falls under"
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

variable "worker_subnet_cidrs" {
  type        = list(string)
  default     = null
  description = "CIDR range for the worker database subnet"
}

### storage account variables
variable "storage_account_name" {
  type        = string
  default     = "indicodatatest"
  description = "Name of the indico storage account"
}

variable "vault_address" {
  type    = string
  default = "https://vault.devops.indico.io"
}

variable "argo_enabled" {
  type    = bool
  default = true
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
  default   = ""
}

variable "argo_repo" {
  description = "Argo Github Repository containing the IPA Application"
  default     = ""
}

variable "argo_branch" {
  description = "Branch to use on argo_repo"
  default     = ""
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
  default = "0.12.1"
}

variable "monitoring_version" {
  type    = string
  default = "0.3.3"
}

variable "ipa_pre_reqs_version" {
  type    = string
  default = "0.4.0"
}

variable "ipa_crds_version" {
  type    = string
  default = "0.2.1"
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
  default     = "1.23.12"
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
    labels                         = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
  }))
}

variable "applications" {
  type = map(object({
    name            = string
    repo            = string
    chart           = string
    version         = string
    values          = string,
    namespace       = string,
    createNamespace = bool,
    vaultPath       = string
  }))
  default = {}
}

variable "harbor_pull_secret_b64" {
  sensitive   = true
  type        = string
  description = "Harbor pull secret from Vault"
}

variable "restore_snapshot_enabled" {
  default     = false
  type        = bool
  description = "Flag for restoring cluster from snapshot"
}

variable "restore_snapshot_name" {
  type        = string
  default     = ""
  description = "Name of snapshot in account's s3 bucket"
}

variable "monitoring_enabled" {
  type        = bool
  default     = true
  description = "Variable to enable the monitoring stack/keda"
}

variable "keda_version" {
  type        = string
  default     = "2.8.1"
  description = "Version of keda helm chart"
}

variable "opentelemetry-collector_version" {
  type        = string
  default     = "0.30.0"
  description = "Version of opentelemetry-collector helm chart"
}

variable "ipa_smoketest_values" {
  type    = string
  default = "Cg==" # empty newline string
}

variable "ipa_smoketest_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "ipa_smoketest_container_tag" {
  type    = string
  default = "IPA-5.4-e1c5af3d"
}

variable "ipa_smoketest_version" {
  type    = string
  default = "0.1.8"
}

variable "ipa_smoketest_slack_channel" {
  type    = string
  default = "cod-smoketest-results"
}

variable "ipa_smoketest_enabled" {
  type    = bool
  default = true
}

variable "ipa_smoketest_cronjob_enabled" {
  type    = bool
  default = false
}

variable "ipa_smoketest_cronjob_schedule" {
  type    = string
  default = "0 0 * * *" # every night at midnight
}

variable "admin_group_name" {
  type        = string
  default     = "DevOps"
  description = "Name of group that will own the cluster"
}

variable "enable_k8s_dashboard" {
  type    = bool
  default = true
}

variable "snapshots_resource_group_name" {
  type    = string
  default = "cod-snapshots"
}

variable "name" {
  type        = string
  default     = "indico"
  description = "Name to use in all cluster resources names"
}

variable "cod_snapshot_restore_version" {
  type    = string
  default = "0.1.3"
}

variable "vault_mount_path" {
  type    = string
  default = "tools/argo"
}

variable "vault_username" {}
variable "vault_password" {
  sensitive = true
}

variable "github_organization" {
  default = "IndicoDataSolutions"
}

variable "ad_group_name" {
  default     = "Engineering"
  description = "Name of an AD group to be mapped if enable_ad_group_mapping is true"
}

variable "enable_ad_group_mapping" {
  type        = bool
  default     = true
  description = "Enable the Mapping of AD Group"
}

#openshift & azure common variables

# enable for openshift
variable "is_openshift" {
  type    = bool
  default = false
}

variable "include_external_dns" {
  type    = bool
  default = true
}

variable "use_workload_identity" {
  type    = bool
  default = true
}
