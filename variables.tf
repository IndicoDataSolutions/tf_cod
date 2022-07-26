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
    createNamespace = bool
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

variable "vault_address" {
  type    = string
  default = "https://vault.devops.indico.io"
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
