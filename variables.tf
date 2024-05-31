
variable "is_azure" {
  type    = bool
  default = false
}

variable "is_aws" {
  type    = bool
  default = true
}

variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "environment" {
  type        = string
  default     = "development"
  description = "The environment of the cluster, determines which account readapi to use, options production/development"
}

variable "message" {
  type        = string
  default     = "Managed by Terraform"
  description = "The commit message for updates"
}

variable "harbor_pull_secret_b64" {
  sensitive   = true
  type        = string
  description = "Harbor pull secret from Vault"
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

# top level variable declarations
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region in which to launch the indico stack"
}

variable "aws_access_key" {
  type        = string
  description = "The AWS access key to use for deployment"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "The AWS secret key to use for deployment"
  sensitive   = true
}

variable "indico_aws_access_key_id" {
  type        = string
  description = "The AWS access key for controlling dns in an alternate account"
  sensitive   = true
  default     = ""
}

variable "indico_aws_secret_access_key" {
  type        = string
  description = "The AWS secret key for controlling dns in an alternate account"
  sensitive   = true
  default     = ""
}

variable "direct_connect" {
  type        = bool
  default     = false
  description = "Sets up the direct connect configuration if true; else use public subnets"
}

variable "additional_tags" {
  type        = map(string)
  default     = null
  description = "Additonal tags to add to each resource"
}

variable "default_tags" {
  type        = map(string)
  default     = null
  description = "Default tags to add to each resource"
}

### networking variables
variable "vpc_cidr" {
  type        = string
  description = "The VPC for the entire indico stack"
}

variable "public_ip" {
  type        = bool
  default     = true
  description = "Should the cluster manager have a public IP assigned"
}

variable "vpc_name" {
  type        = string
  default     = "indico_vpc"
  description = "The VPC name"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the private subnets"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges for the public subnets"
}

variable "subnet_az_zones" {
  type        = list(string)
  description = "Availability zones for the subnets"
}

### storage
variable "storage_gateway_size" {
  type        = string
  default     = "m5.xlarge"
  description = "The size of the storage gateway VM"
}

variable "existing_kms_key" {
  type        = string
  default     = ""
  description = "Name of kms key if it exists in the account (eg. 'alias/<name>')"
}

### database
variable "bucket_versioning" {
  type        = bool
  default     = true
  description = "Enable bucket object versioning"
}

variable "submission_expiry" {
  type        = number
  description = "The number of days to retain submissions"
  default     = 30
}

variable "uploads_expiry" {
  type        = number
  description = "The number of days to retain uploads"
  default     = 30
}

### cluster
variable "name" {
  type        = string
  default     = "indico"
  description = "Name to use in all cluster resources names"
}

variable "cluster_name" {
  type        = string
  default     = "indico-cluster"
  description = "Name of the EKS cluster"
}

variable "k8s_version" {
  type        = string
  default     = "1.29"
  description = "The EKS version to use"
}

variable "node_groups" {
}

variable "node_bootstrap_arguments" {
  default     = ""
  description = "Additional arguments when bootstrapping the EKS node."
}

variable "node_user_data" {
  default     = ""
  description = "Additional user data used when bootstrapping the EC2 instance."
}

variable "node_disk_size" {
  default     = "150"
  description = "The root device size for the worker nodes."
}

variable "cluster_node_policies" {
  type        = list(any)
  default     = ["IAMReadOnlyAccess"]
  description = "Additonal IAM policies to add to the cluster IAM role"
}

variable "kms_encrypt_secrets" {
  type        = bool
  default     = true
  description = "Encrypt EKS secrets with KMS"
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
  type    = string
  default = ""
}
variable "azure_indico_io_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "azure_indico_io_subscription_id" {
  type    = string
  default = ""
}
variable "azure_indico_io_tenant_id" {
  type    = string
  default = ""
}

# IAM
variable "eks_cluster_iam_role" {
  type        = string
  default     = null
  description = "Name of the IAM role to assign to the EKS cluster; will be created if not supplied"
}

variable "eks_cluster_nodes_iam_role" {
  type        = string
  default     = null
  description = "Name of the IAM role to assign to the EKS cluster nodes; will be created if not supplied"
}

# FSx storage capacity for wrx volume
variable "storage_capacity" {
  type        = number
  default     = 1200
  description = "Storage capacity in GiB for RWX FSx"
}

variable "deletion_protection_enabled" {
  type        = bool
  default     = true
  description = "Enable deletion protection if set to true"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = "Skip taking a final snapshot before deletion; not recommended to enable"
}

variable "per_unit_storage_throughput" {
  type        = number
  default     = 100
  description = "Throughput for each 1 TiB or storage (max 200) for RWX FSx"
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of availability zones for nodes"

  validation {
    condition     = var.az_count > 0 && var.az_count <= 3
    error_message = "The az_count must be in the range 1-3"
  }
}

variable "snapshot_id" {
  type        = string
  default     = ""
  description = "The ebs snapshot of read-only data to use"
}

variable "include_rox" {
  type        = bool
  default     = false
  description = "Create a read only FSx file system"
}

variable "aws_account" {
  type        = string
  description = "The Name of the AWS Acccount this cluster lives in"
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
  default   = "not used"
}

variable "argo_repo" {
  description = "Argo Github Repository containing the IPA Application"
  default     = ""
}

variable "argo_branch" {
  description = "Branch to use on argo_repo"
  default     = ""
}

variable "argo_namespace" {
  type    = string
  default = "argo"
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
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "ipa_version" {
  type    = string
  default = "0.12.1"
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
  default = "0.1.8"
}

variable "ipa_smoketest_enabled" {
  type    = bool
  default = true
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

variable "vault_address" {
  type    = string
  default = "https://vault.devops.indico.io"
}

variable "vault_username" {}
variable "vault_password" {
  sensitive = true
}

variable "sqs_sns" {
  type        = bool
  default     = true
  description = "Flag for enabling SQS/SNS"
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

## OIDC Configuration
variable "oidc_enabled" {
  type        = bool
  default     = true
  description = "Enable OIDC Auhentication"
}

variable "oidc_client_id" {
  default = "kube-oidc-proxy"
}

variable "oidc_config_name" {
  default = "indico-google-ws"
}

variable "oidc_issuer_url" {
  default = "https://keycloak.devops.indico.io/auth/realms/GoogleAuth"
}

variable "oidc_groups_prefix" {
  default = "oidcgroup:"
}

variable "oidc_groups_claim" {
  default = "groups"
}

variable "oidc_username_prefix" {
  default = "oidcuser:"
}

variable "oidc_username_claim" {
  default = "sub"
}

variable "monitoring_enabled" {
  type    = bool
  default = true
}

variable "hibernation_enabled" {
  type    = bool
  default = false
}

variable "keda_version" {
  default = "2.13.2"
}

variable "external_secrets_version" {
  type        = string
  default     = "0.9.9"
  description = "Version of external-secrets helm chart"
}

variable "opentelemetry-collector_version" {
  default = "0.30.0"
}

variable "include_fsx" {
  type        = bool
  default     = false
  description = "Create a fsx file system(s)"
}

variable "include_pgbackup" {
  type        = bool
  default     = true
  description = "Create a read only FSx file system"
}

variable "include_efs" {
  type        = bool
  default     = true
  description = "Create efs"
}

#Added to support dop-1500 - QA needs programmatic access to push data to the s3 bucket indico-locust-benchmark-test-results in us-east-2.
variable "performance_bucket" {
  type        = bool
  default     = false
  description = "Add permission to connect to indico-locust-benchmark-test-results"
}
variable "crds-values-yaml-b64" {
  default = "Cg=="
}

variable "pre-reqs-values-yaml-b64" {
  default = "Cg=="
}
variable "k8s_dashboard_chart_version" {
  default = "0.1.0"
}

variable "enable_k8s_dashboard" {
  type    = bool
  default = true
}

variable "use_acm" {
  type        = bool
  default     = false
  description = "create cluster that will use acm"
}

variable "enable_waf" {
  type        = bool
  default     = false
  description = "enables aws alb controller for app-edge, also creates waf rules."
}

variable "vault_mount_path" {
  type    = string
  default = "terraform"
}

variable "terraform_vault_mount_path" {
  type    = string
  default = "terraform"
}

variable "aws_primary_dns_role_arn" {
  type        = string
  default     = ""
  description = "The AWS arn for the role needed to manage route53 DNS in a different account."
}

variable "is_alternate_account_domain" {
  type        = string
  default     = "false"
  description = "domain name is controlled by a different aws account"
}

variable "domain_suffix" {
  type        = string
  default     = "indico.io"
  description = "Domain suffix"
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
  default     = "blank"
  description = "Secret url with embedded token needed for slack webhook delivery."
}

variable "alerting_slack_channel" {
  type        = string
  default     = "blank"
  description = "Slack channel for sending notifications from alertmanager."
}

variable "alerting_pagerduty_integration_key" {
  type        = string
  default     = "blank"
  description = "Secret pagerduty_integration_key."
}

variable "alerting_email_from" {
  type        = string
  default     = "blank"
  description = "alerting_email_from."
}

variable "alerting_email_to" {
  type        = string
  default     = "blank"
  description = "alerting_email_to"
}

variable "alerting_email_host" {
  type        = string
  default     = "blank"
  description = "alerting_email_host"
}

variable "alerting_email_username" {
  type        = string
  default     = "blank"
  description = "alerting_email_username"
}

variable "alerting_email_password" {
  type        = string
  default     = "blank"
  description = "alerting_email_password"
}

variable "eks_addon_version_guardduty" {
  type        = bool
  default     = true
  description = "enable guardduty"
}

variable "use_static_ssl_certificates" {
  type        = bool
  default     = false
  description = "use static ssl certificates for clusters which cannot use certmanager and external dns."
}

variable "ssl_static_secret_name" {
  type        = string
  default     = "indico-ssl-static-cert"
  description = "secret_name for static ssl certificate"
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


variable "thanos_cluster_name" {
  type    = string
  default = "thanos"
}

variable "indico_devops_aws_access_key_id" {
  type        = string
  description = "The Indico-Devops account access key"
  sensitive   = true
  default     = ""
}

variable "indico_devops_aws_secret_access_key" {
  type        = string
  description = "The Indico-Devops account secret"
  sensitive   = true
  default     = ""
}

variable "indico_devops_aws_region" {
  type        = string
  description = "The Indico-Devops devops cluster region"
  default     = ""
}

variable "thanos_enabled" {
  type    = bool
  default = true
}

variable "keycloak_enabled" {
  type    = bool
  default = true
}

variable "terraform_smoketests_enabled" {
  type    = bool
  default = true
}

variable "on_prem_test" {
  type    = bool
  default = false
}
variable "harness_delegate" {
  type    = bool
  default = false
}

variable "harness_delegate_replicas" {
  type    = number
  default = 1
}

variable "harness_mount_path" {
  type    = string
  default = "harness"
}

variable "enable_s3_backup" {
  type        = bool
  default     = true
  description = "Allow backing up data bucket on s3"
}

variable "network_allow_public" {
  type        = bool
  default     = true
  description = "If enabled this will create public subnets, IGW, and NAT gateway."
}

variable "network_module" {
  type    = string
  default = "networking"

  validation {
    condition     = var.network_module == "public_networking" || var.network_module == "networking"
    error_message = "${var.network_module} not valid. Type must be either public_networking or networking"
  }
}

variable "network_type" {
  type    = string
  default = "create"

  validation {
    condition     = var.network_type == "create" || var.network_type == "load"
    error_message = "${var.network_type} not valid. Type must be either create or load"
  }
}

variable "sg_type" {
  type    = string
  default = "load"

  validation {
    condition     = var.sg_type == "create" || var.sg_type == "load"
    error_message = "${var.sg_type} not valid. Type must be either create or load"
  }
}

variable "load_vpc_id" {
  type        = string
  default     = ""
  description = "This is required if loading a network rather than creating one."
}

variable "private_subnet_tag_name" {
  type    = string
  default = "Name"
}

variable "private_subnet_tag_value" {
  type    = string
  default = "*private*"
}

variable "public_subnet_tag_name" {
  type    = string
  default = "Name"
}

variable "public_subnet_tag_value" {
  type    = string
  default = "*public*"
}

variable "sg_tag_name" {
  type    = string
  default = "Name"
}

variable "sg_tag_value" {
  type    = string
  default = "*-allow-subnets"
}

variable "s3_endpoint_enabled" {
  type        = bool
  default     = false
  description = "If set to true, an S3 VPC endpoint will be created. If this variable is set, the `region` variable must also be set"
}

variable "image_registry" {
  type        = string
  default     = "harbor.devops.indico.io"
  description = "docker image registry to use for pulling images."
}

variable "secrets_operator_enabled" {
  type        = bool
  default     = true
  description = "Use to enable the secrets operator which is used for maintaining thanos connection"
}

variable "firewall_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR ranges for the firewall subnets"
}

variable "enable_firewall" {
  type        = bool
  default     = false
  description = "If enabled this will create firewall and internet gateway"
}

variable "firewall_allow_list" {
  type    = list(string)
  default = [".cognitiveservices.azure.com"]
}

variable "dns_zone_name" {
  type        = string
  default     = ""
  description = "Name of the dns zone used to control DNS"
}

variable "readapi_customer" {
  type        = string
  default     = null
  description = "Name of the customer readapi is being deployed in behalf."
}