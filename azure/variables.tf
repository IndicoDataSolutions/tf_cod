#
variable "do_create_cluster" {
  type    = bool
  default = true
}


variable "is_azure" {
  type    = bool
  default = true
}

variable "is_aws" {
  type    = bool
  default = false
}

variable "environment" {
  type        = string
  default     = "development"
  description = "The environment of the cluster, determines which account readapi to use, options production/development"
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
  default     = "indico-dev-azure"
  description = "The name of the subscription that this cluster falls under"
}

variable "region" {
  type        = string
  default     = "eastus"
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
  default     = null
  description = "CIDR range for the worker database subnet"
}

### storage account variables
variable "storage_account_name" {
  type        = string
  default     = ""
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

variable "argo_namespace" {
  type    = string
  default = "argo"
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
  default = "3.0.0"
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

variable "crds-values-yaml-b64" {
  default = "Cg=="
}

variable "pre-reqs-values-yaml-b64" {
  default = "Cg=="
}

### cluster variables
variable "private_cluster_enabled" {
  type        = bool
  default     = false
  description = "If enabled, the cluster will be launched as a private cluster"
}

variable "private_cluster_dns_override" {
  type        = bool
  default     = false
  description = "If enabled, the cluster will use dns_prefix instead of dns_prefix_private_cluster even if private_cluster_enabled is set to true"
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
  default     = "1.31"
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
    labels                         = map(string)
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
  default     = "2.13.2"
  description = "Version of keda helm chart"
}

variable "external_secrets_version" {
  type        = string
  default     = "0.9.9"
  description = "Version of external-secrets helm chart"
}

variable "opentelemetry_collector_version" {
  type        = string
  default     = "0.97.1"
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

variable "ipa_smoketest_version" {
  type    = string
  default = "0.2.1-add-openshift-crds-4a0b2155"
}

variable "ipa_smoketest_slack_channel" {
  type    = string
  default = "cod-smoketest-results"
}

variable "ipa_smoketest_enabled" {
  type    = bool
  default = true
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
  default = "0.1.5"
}

variable "vault_mount_path" {
  type    = string
  default = null
}

variable "vault_username" {
}
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

# ReadAPI stuff
variable "enable_readapi" {
  type    = bool
  default = true
}
variable "azure_readapi_client_id" {
  type    = string
  default = ""
}
variable "azure_readapi_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "azure_readapi_subscription_id" {
  type    = string
  default = ""
}
variable "azure_readapi_tenant_id" {
  type    = string
  default = ""
}

# Old provider configuration to remove orphaned readapi resources
variable "azure_indico_io_client_id" {
  type = string
}
variable "azure_indico_io_client_secret" {
  type      = string
  sensitive = true
}
variable "azure_indico_io_subscription_id" {
  type = string
}
variable "azure_indico_io_tenant_id" {
  type = string
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

variable "openshift_pull_secret" {
  type    = string
  default = ""
}

variable "servicebus_pricing_tier" {
  type        = string
  default     = "Standard"
  description = "pricing tier for service bus, options are Basic, Standard or Premium. Premium should be used for production clusters"
}

variable "servicebus_message_filter" {
  type        = map(string)
  default     = null
  description = "filter for servicebus messages"
}

variable "enable_servicebus" {
  type    = bool
  default = false
}

variable "is_alternate_account_domain" {
  type        = string
  default     = "false"
  description = "domain name is controlled by a different aws account"
}

variable "domain_host" {
  type        = string
  default     = ""
  description = "domain host name."
}

variable "alerting_enabled" {
  type        = bool
  default     = false
  description = "enable alerts"
}

variable "alerting_slack_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via slack"
}

variable "alerting_pagerduty_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via pagerduty"
}

variable "alerting_email_enabled" {
  type        = bool
  default     = false
  description = "enable alerts via email"
}

variable "alerting_slack_token" {
  type        = string
  default     = ""
  description = "Secret url with embedded token needed for slack webhook delivery."
}

variable "alerting_slack_channel" {
  type        = string
  default     = ""
  description = "Slack channel for sending notifications from alertmanager."
}

variable "alerting_pagerduty_integration_key" {
  type        = string
  default     = ""
  description = "Secret pagerduty_integration_key."
}

variable "alerting_email_from" {
  type        = string
  default     = ""
  description = "alerting_email_from."
}

variable "alerting_email_to" {
  type        = string
  default     = ""
  description = "alerting_email_to"
}

variable "alerting_email_host" {
  type        = string
  default     = ""
  description = "alerting_email_host"
}

variable "alerting_email_username" {
  type        = string
  default     = ""
  description = "alerting_email_username"
}

variable "alerting_email_password" {
  type        = string
  default     = ""
  description = "alerting_email_password"
}

variable "monitor_retention_in_days" {
  type        = number
  default     = 30 # minimum value
  description = "Azure Monitor retention in days"
}


variable "local_registry_version" {
  type    = string
  default = "unused"
}

variable "local_registry_enabled" {
  type    = bool
  default = false
}

variable "devops_tools_cluster_host" {
  type    = string
  default = "provided from the varset devops-tools-cluster"
}

variable "devops_tools_cluster_ca_certificate" {
  type      = string
  sensitive = true
  default   = "provided from the varset devops-tools-cluster"
}

variable "thanos_grafana_admin_username" {
  type    = string
  default = "provided from the varset devops-tools-cluster"
}

variable "thanos_grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "provided from the varset thanos"
}

variable "thanos_cluster_ca_certificate" {
  type      = string
  sensitive = true
  default   = "provided from the varset thanos"
}

variable "thanos_cluster_host" {
  type    = string
  default = "provided from the varset thanos"
}

variable "indico_devops_aws_access_key_id" {
  type        = string
  description = "The Indico-Devops account access key"
  sensitive   = true
}

variable "indico_devops_aws_secret_access_key" {
  type        = string
  description = "The Indico-Devops account secret"
  sensitive   = true
}

variable "indico_devops_aws_region" {
  type        = string
  description = "The Indico-Devops devops cluster region"
}

variable "thanos_cluster_name" {
  type    = string
  default = "thanos"
}

variable "thanos_enabled" {
  type    = bool
  default = true
}

variable "harness_delegate" {
  type    = bool
  default = false
}

variable "harness_mount_path" {
  type    = string
  default = "harness"
}

variable "terraform_smoketests_enabled" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type    = string
  default = null
}

variable "create_resource_group" {
  type    = bool
  default = true
}

variable "use_static_ssl_certificates" {
  type    = bool
  default = false
}

variable "ssl_static_secret_name" {
  type        = string
  default     = "indico-ssl-static-cert"
  description = "secret_name for static ssl certificate"
}

# Log analytics

variable "sentinel_workspace_name" {
  type    = string
  default = null # "${var.account}-sentinel-workspace"
}

variable "sentinel_workspace_resource_group_name" {
  type    = string
  default = null # "${var.account}-sentinel-group"
}


variable "image_registry" {
  type        = string
  default     = "harbor.devops.indico.io"
  description = "docker image registry to use for pulling images."
}

variable "sentinel_workspace_id" {
  type    = string
  default = null
}

### cluster manager variables
variable "cluster_manager_vm_size" {
  type        = string
  default     = "Standard_Fs_v2"
  description = "The cluster manager instance size"
}

variable "network_type" {
  type    = string
  default = "create"
}

variable "network_resource_group_name" {
  type    = string
  default = null
}

variable "virtual_network_name" {
  default = null
  type    = string
}

variable "virtual_subnet_name" {
  default = null
  type    = string
}

variable "keyvault_name" {
  default = null
  type    = string
}

variable "network_plugin" {
  default = "kubenet"
  type    = string
}

variable "network_plugin_mode" {
  default = null
  type    = string
}
variable "enable_custom_cluster_issuer" {
  default = false
  type    = bool
}

variable "custom_cluster_issuer_spec" {
  default = ""
  type    = string
}

variable "private_dns_zone" {
  default = false
  type    = bool
}

variable "private_cluster_public_fqdn_enabled" {
  default = false
  type    = bool
}

variable "cluster_outbound_type" {
  default = "loadBalancer"
  type    = string
}

variable "enable_external_dns" {
  default = true
  type    = bool
}

variable "private_dns_zone_id" {
  default = "System"
  type    = string
}

variable "sku_tier" {
  default = "Standard"
  type    = string
}

variable "cluster_service_cidr" {
  type    = string
  default = null
}

variable "dns_service_ip" {
  type    = string
  default = null
}

variable "docker_bridge_cidr" {
  type    = string
  default = null
}

variable "secrets_operator_enabled" {
  type        = bool
  default     = true
  description = "Use to enable the secrets operator which is used for maintaining thanos connection"
}

variable "vault_secrets_operator_version" {
  type    = string
  default = "0.7.0"
}

variable "aks_storage_account_name" {
  type        = string
  default     = ""
  description = "specifies the storage account name for the cluster if we don't want it generated automatically"
}
