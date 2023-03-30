variable "is_openshift" { type = bool }
variable "ipa_values" { type = string }
variable "label" { type = string }
variable "region" { type = string }
variable "account" { type = string }
variable "domain_suffix" { type = string }
variable "k8s_version" { type = string }
variable "cluster_type" { type = string }
variable "github_organization" { type = string }
variable "ipa_repo" { type = string }
variable "ipa_version" { type = string }
variable "ipa_pre_reqs_version" { type = string }
variable "ipa_crds_version" { type = string }
variable "ipa_namespace" { type = string }
variable "ipa_enabled" { type = bool }
variable "monitoring_namespace" { type = string }

variable "argo_repo" { type = string }
variable "argo_branch" { type = string }
variable "argo_path" { type = string }
variable "argo_enabled" { type = bool }
variable "message" { type = string }
variable "kubernetes_host" { type = string }
variable "kubelet_identity_client_id" { type = string }
variable "kubelet_identity_object_id" { type = string }
variable "storage_account_name" { type = string }
variable "fileshare_name" { type = string }
variable "storage_account_primary_access_key" { type = string }
variable "blob_store_name" { type = string }
variable "vault_mount_path" { type = string }

variable "monitoring_username" { type = string }
variable "monitoring_password" { type = string }

variable "harbor_pull_secret_b64" {
  sensitive = true
  type      = string
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
}





