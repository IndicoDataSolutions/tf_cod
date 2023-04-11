
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

variable "user_ip" {
  type        = string
  default     = ""
  description = "The IP address to allow SSH access for"
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

variable "multi_az" {
  type        = bool
  default     = true
  description = "Enable a multi-availability zone deployment"
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

variable "cluster_version" {
  type        = string
  default     = "1.23"
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
  default     = []
  description = "Additonal IAM policies to add to the cluster IAM role"
}

variable "kms_encrypt_secrets" {
  type        = bool
  default     = true
  description = "Encrypt EKS secrets with KMS"
}


# IAM
variable "cluster_manager_iam_role" {
  type        = string
  default     = null
  description = "Name of the IAM role to assign to the cluster manager EC2 instance; will be created if not supplied"
}

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
variable "node_group_multi_az" {
  type        = bool
  default     = true
  description = "Enable a multi-availability zone deployment for nodes"
}

variable "snapshot_id" {
  type        = string
  default     = ""
  description = "The ebs snapshot of read-only data to use"
}

variable "include_rox" {
  type        = bool
  default     = true
  description = "Create a read only FSx file system"
}

variable "assumed_roles" {
  type        = list(string)
  default     = null
  description = "list of ARNs to be put in the trust relationship for the cluster manager role"
}

variable "aws_account" {
  type        = string
  description = "The Name of the AWS Acccount this cluster lives in"
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
  default = "2.8.1"
}

variable "opentelemetry-collector_version" {
  default = "0.30.0"
}

variable "include_fsx" {
  type        = bool
  default     = true
  description = "Create a fsx file system(s)"
}

variable "include_pgbackup" {
  type        = bool
  default     = true
  description = "Create a read only FSx file system"
}

variable "include_efs" {
  type        = bool
  default     = false
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


variable "terraform_vault_mount_path" {
  type    = string
  default = "terraform"
}

variable "snowflake_region" {
  default     = "us-east-2.aws"
  type        = string
  description = "region the snowflake instance resides"
}

variable "snowflake_username" {
  default     = "tf-snow"
  type        = string
  description = "snowflake master username"
}

variable "snowflake_account" {
  default     = "ZL54998"
  type        = string
  description = "account identifier"
}

variable "snowflake_private_key" {
  default     = null
  type        = string
  description = "Private Key for username+private-key snowflake auth"
}

variable "snowflake_db_name" {
  type        = string
  default     = "INDICO_DEV"
  description = "the db name that snowflake resources will be connected with"
}

variable "enable_weather_station" {
  type        = bool
  default     = false
  description = "whether or not to enable the weather station internal metrics collection service"
}

variable "aws_primary_dns_role_arn" {
  type        = string
  default     = ""
  description = "The AWS arn for the role needed to manage route53 DNS in a different account."
}

variable "alternate_domain" {
  type        = string
  default     = ""
  description = "Optional alternate domain to use with cluster."
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

