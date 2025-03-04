
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

variable "aws_session_token" {
  type        = string
  description = "The AWS session token to use for deployment"
  sensitive   = true
  default     = null
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

variable "indico_aws_session_token" {
  type        = string
  description = "The AWS session token to use for deployment in an alternate account"
  sensitive   = true
  default     = null
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
  default     = "1.31"
  description = "The EKS version to use"
}

variable "node_groups" {
  default     = null
  description = "Override for the node groups assigned to the cluster. If not supplied, the node groups will be determined from intake and insights defaults"
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
  type    = string
  default = "2.15.2"
}

variable "external_secrets_version" {
  type        = string
  default     = "0.10.5"
  description = "Version of external-secrets helm chart"
}

variable "opentelemetry_collector_version" {
  type    = string
  default = "0.108.0"
}

variable "nfs_subdir_external_provisioner_version" {
  type        = string
  default     = "4.0.18"
  description = "Version of nfs_subdir_external_provisioner_version helm chart"
}

variable "csi_driver_nfs_version" {
  type        = string
  default     = "v4.0.9"
  description = "Version of csi-driver-nfs helm chart"
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

variable "enable_k8s_dashboard" {
  type    = bool
  default = true
}

variable "use_acm" {
  type        = bool
  default     = false
  description = "create cluster that will use acm"
}

variable "acm_arn" {
  type        = string
  default     = ""
  description = "arn of a pre-existing acm certificate"
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

variable "indico_devops_aws_session_token" {
  type        = string
  description = "Indico-Devops account AWS session token to use for deployment"
  sensitive   = true
  default     = null
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

variable "lambda_sns_forwarder_enabled" {
  type        = bool
  default     = false
  description = "If enabled a lamda will be provisioned to forward sns messages to an external endpoint."
}

variable "lambda_sns_forwarder_destination_endpoint" {
  type        = string
  default     = ""
  description = "destination URL for the lambda sns forwarder"
}

variable "lambda_sns_forwarder_topic_arn" {
  type        = string
  default     = ""
  description = "SNS topic to triger lambda forwarder."
}

variable "lambda_sns_forwarder_github_organization" {
  type        = string
  default     = "IndicoDataSolutions"
  description = "The github organization containing the lambda_sns_forwarder code to use"
}

variable "lambda_sns_forwarder_github_repository" {
  type        = string
  default     = ""
  description = "The github repository containing the lambda_sns_forwarder code to use"
}

variable "lambda_sns_forwarder_github_branch" {
  type        = string
  default     = "main"
  description = "The github branch / tag containing the lambda_sns_forwarder code to use"
}

variable "lambda_sns_forwarder_github_zip_path" {
  type        = string
  default     = "zip/lambda.zip"
  description = "Full path to the lambda zip file"
}

variable "lambda_sns_forwarder_function_variables" {
  type        = map(any)
  default     = {}
  description = "A map of variables for the lambda_sns_forwarder code to use"
}

variable "enable_s3_backup" {
  type        = bool
  default     = true
  description = "Allow backing up data bucket on s3"
}

variable "cluster_api_endpoint_public" {
  type        = bool
  default     = true
  description = "If enabled this allow public access to the cluster api endpoint."
}

variable "network_allow_public" {
  type        = bool
  default     = true
  description = "If enabled this will create public subnets, IGW, and NAT gateway."
}

variable "internal_elb_use_public_subnets" {
  type        = bool
  default     = true
  description = "If enabled, this will use public subnets for the internal elb. Otherwise use the private subnets"
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

variable "vault_secrets_operator_version" {
  type    = string
  default = "0.7.0"
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

variable "create_guardduty_vpc_endpoint" {
  type        = bool
  default     = true
  description = "If true this will create a vpc endpoint for guardduty."
}

variable "use_nlb" {
  type        = bool
  default     = false
  description = "If true this will create a NLB loadbalancer instead of a classic VPC ELB"
}

variable "enable_s3_access_logging" {
  type        = bool
  default     = true
  description = "If true this will enable access logging on the s3 buckets"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "If enabled this will create flow logs for the VPC"
}

variable "vpc_flow_logs_iam_role_arn" {
  type        = string
  default     = ""
  description = "The IAM role to use for the flow logs"
}
variable "instance_volume_size" {
  type        = number
  default     = 60
  description = "The size of EBS volume to attach to the cluster nodes"
}

variable "instance_volume_type" {
  type        = string
  default     = "gp2"
  description = "The type of EBS volume to attach to the cluster nodes"
}

variable "sqs_sns_type" {
  type    = string
  default = "create"
  validation {
    condition     = var.sqs_sns_type == "create" || var.sqs_sns_type == "load"
    error_message = "${var.sqs_sns_type} not valid. Type must be either create or load"
  }
}

variable "ipa_sns_topic_name" {
  type        = string
  description = "Full name of the SNS topic"
  default     = null
}

variable "ipa_sqs_queue_name" {
  type        = string
  description = "Full name of the SQS queue"
  default     = null
}

variable "indico_sqs_sns_policy_name" {
  type        = string
  description = "Full name of the SQS SNS policy"
  default     = null
}

variable "additional_users" {
  type        = list(string)
  default     = []
  description = "The names of additional AWS users to provide admin access to the cluster"
}


## Unused variables

variable "aws_account_name" {
  type    = string
  default = ""
}

variable "access_key" {
  type    = string
  default = ""
}

variable "secret_key" {
  type    = string
  default = ""
}

variable "cluster_type" {
  type    = string
  default = "EKS"
}

variable "argo_bcrypt_password" {
  type    = string
  default = ""
}

variable "harbor_admin_password" {
  type    = string
  default = ""
}

variable "azure_indico_io_client_secret_id" {
  type    = string
  default = ""
}

variable "az_readapi_subscription_id" {
  type    = string
  default = ""
}

variable "az_readapi_client_id" {
  type    = string
  default = ""
}

variable "az_readapi_client_secret_id" {
  type    = string
  default = ""
}

variable "aws_account_ids" {
  type    = list(string)
  default = []
}

variable "ipa_smoketest_cronjob_enabled" {
  type    = bool
  default = false
}

variable "local_registry_harbor_robot_account_name" {
  type    = string
  default = ""
}

variable "bucket_type" {
  type    = string
  default = "create"
  validation {
    condition     = var.bucket_type == "create" || var.bucket_type == "load"
    error_message = "${var.bucket_type} not valid. Type must be either create or load"
  }
}

variable "data_s3_bucket_name_override" {
  type        = string
  default     = null
  description = "The name of the existing S3 bucket to be created/loaded and used as the data bucket"
}

variable "s3_backup_role_name_override" {
  type        = string
  default     = null
  description = "The name of the existing S3 backup role"
}

variable "create_s3_backup_role" {
  type        = bool
  default     = true
  description = "Flag to create or load s3 backup role"
}

variable "create_vpc_flow_logs_role" {
  type        = bool
  default     = true
  description = "Flag to create or load vpc flow logs role"
}

variable "vpc_flow_logs_role_name_override" {
  type        = string
  default     = null
  description = "The name of the existing vpc flow logs role"
}

variable "create_eks_cluster_role" {
  type        = bool
  default     = true
  description = "Flag to create or load eks cluster role"
}

variable "eks_cluster_iam_role_name_override" {
  type        = string
  default     = null
  description = "The name of the existing eks cluster role"
}

variable "api_models_s3_bucket_name_override" {
  type        = string
  default     = null
  description = "The name of the existing S3 bucket to be created/loaded and used as the API model bucket"
}

variable "pgbackup_s3_bucket_name_override" {
  type        = string
  default     = null
  description = "The name of the existing S3 bucket to be created/loaded and used as the postgres backup bucket"
}

# Additional variables
variable "enable_s3_replication" {
  type        = bool
  default     = false
  description = "Flag to enable s3 replication"
}

variable "create_s3_replication_role" {
  type        = bool
  default     = true
  description = "Flag to create or load s3 replication role"
}

variable "s3_replication_role_name_override" {
  type        = string
  default     = null
  description = "Name override for s3 replication role"
}

variable "destination_kms_key_arn" {
  type        = string
  default     = ""
  description = "arn of kms key used to encrypt s3 replication destination buckets"
}

variable "data_destination_bucket" {
  type        = string
  default     = ""
  description = "s3 replication data destination bucket"
}

variable "api_model_destination_bucket" {
  type        = string
  default     = ""
  description = "s3 replication api model destination bucket"
}

# Node role
variable "create_node_role" {
  type        = bool
  default     = true
  description = "Flag to create or load node role"
}

variable "node_role_name_override" {
  type        = string
  default     = null
  description = "Name override for node role"
}

variable "fsx_deployment_type" {
  type        = string
  default     = "PERSISTENT_1"
  description = "The deployment type to launch"
}

variable "fsx_type" {
  type    = string
  default = "create"
  validation {
    condition     = var.fsx_type == "create" || var.fsx_type == "load"
    error_message = "${var.fsx_type} not valid. Type must be either create or load"
  }
}

variable "fsx_rwx_id" {
  description = "ID of the existing FSx Lustre file system for RWX"
  type        = string
  default     = null
}

variable "fsx_rwx_subnet_ids" {
  description = "Subnet IDs for the RWX FSx Lustre file system"
  type        = list(string)
  default     = []
}

variable "fsx_rwx_security_group_ids" {
  description = "Security group IDs for the RWX FSx Lustre file system"
  type        = list(string)
  default     = []
}

variable "fsx_rwx_dns_name" {
  description = "DNS name for the RWX FSx Lustre file system"
  type        = string
  default     = null
}

variable "fsx_rwx_mount_name" {
  description = "Mount name for the RWX FSx Lustre file system"
  type        = string
  default     = null
}

variable "fsx_rwx_arn" {
  description = "ARN of the RWX FSx Lustre file system"
  type        = string
  default     = null
}

variable "fsx_rox_id" {
  description = "ID of the existing FSx Lustre file system for ROX"
  type        = string
  default     = null
}

variable "fsx_rox_arn" {
  description = "ARN of the ROX FSx Lustre file system"
  type        = string
  default     = null
}

variable "efs_filesystem_name" {
  type        = string
  default     = ""
  description = "The filesystem name of an existing efs instance"
}

variable "efs_type" {
  type    = string
  default = "create"

  validation {
    condition     = var.efs_type == "create" || var.efs_type == "load"
    error_message = "${var.efs_type} not valid. Type must be either create or load"
  }
}

variable "indico_crds_version" {
  type        = string
  default     = ""
  description = "Version of the indico-crds helm chart"
}

variable "indico_pre_reqs_version" {
  type        = string
  default     = ""
  description = "Version of the indico-pre-reqs helm chart"
}

variable "insights-pre-reqs-values-yaml-b64" {
  type        = string
  default     = "Cg=="
  description = "user provided overrides to indico-pre-reqs helm chart"
}

variable "insights_enabled" {
  type        = bool
  default     = false
  description = "Toggle for enabling insights deployment"
}

variable "insights_values" {
  type        = string
  default     = ""
  description = "User provided overrides to the insights application"
}

variable "insights_version" {
  type        = string
  default     = ""
  description = "Insights helm chart version to deploy to the cluster"
}

variable "insights_smoketest_version" {
  type        = string
  default     = ""
  description = "Insights smoketest to deploy to the cluster"
}

variable "insights_smoketest_values" {
  type        = string
  default     = ""
  description = "Insights smoketest overrides"
}

variable "insights_smoketest_enabled" {
  type        = bool
  default     = false
  description = "Toggle for enabling smoketest"
}

variable "insights_smoketest_cronjob_enabled" {
  type        = bool
  default     = false
  description = "Toggle for scheduling smoketests"
}

variable "insights_pre_reqs_version" {
  type        = string
  default     = ""
  description = "insights-pre-requisites helm chart version"
}

variable "insights_local_registry_harbor_robot_account_name" {
  type        = string
  default     = ""
  description = ""
}

variable "insights_local_registry_enabled" {
  type        = string
  default     = ""
  description = ""
}

variable "minio_enabled" {
  type        = bool
  default     = false
  description = "Toggle for enabling minio deployment"
}

variable "indico-crds-values-yaml-b64" {
  default = "Cg=="
}

variable "indico-pre-reqs-values-yaml-b64" {
  default = "Cg=="
}

variable "include_miniobkp" {
  type        = string
  default     = true
  description = "If true this will create a miniobkp bucket"
}

variable "miniobkp_s3_bucket_name_override" {
  type        = string
  default     = null
  description = "The name of the existing S3 bucket to be loaded and used as the minio backup bucket"
}
