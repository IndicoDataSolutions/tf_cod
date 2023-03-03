
variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

variable "region" {
  type        = string
  default     = "eastus"
  description = "The Azure region in which to launch the indico stack"
}

variable "account" {
  type        = string
  default     = "Azure-Dev"
  description = "The name of the subscription that this cluster falls under"
}

variable "domain_suffix" {
  type        = string
  default     = "indico.io"
  description = "Domain suffix"
}

variable "k8s_version" {
  type        = string
  default     = "1.23.12"
  description = "The version of the kubernetes cluster"
}

variable "cluster_type" {
  type    = string
  default = "openshift-azure"
}

variable "argo_enabled" {
  type    = bool
  default = true
}

variable "github_organization" {
  default = "IndicoDataSolutions"
}

variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts-dev"
}

variable "ipa_version" {
  type    = string
  default = "0.12.1"
}

variable "ipa_pre_reqs_version" {
  type    = string
  default = "0.4.0"
}

variable "ipa_crds_version" {
  type    = string
  default = "0.2.1"
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

variable "commit_message" {
  type        = string
  default     = "Managed by Terraform"
  description = "The commit message for updates"
}

variable "storage_key_secret" {
  description = "Value of the storage key secret to access the storage account"
  sensitive   = true
  type        = string
}

variable "harbor_pull_secret_b64" {
  sensitive   = true
  type        = string
  description = "Harbor pull secret from Vault"
}

variable "kubernetes_host" {
  type        = string
  description = "Kubernetes API host"
}

variable "kubelet_identity_client_id" {
  type        = string
  description = "Cluster kubelet sp client id"
}

variable "kubelet_identity_object_id" {
  type        = string
  description = "Cluster kubelet sp client id"
}

variable "storage_account_name" {
  type        = string
  description = "Cluster kubelet sp object id"
}

variable "fileshare_name" {
  type        = string
  description = "Name of storage account fileshare"
}

variable "storage_account_primary_access_key" {
  type        = string
  description = "Read variable name"
}

variable "blob_store_name" {
  type        = string
  description = "Storage account blob store name"
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





