variable "do_create_cluster" {
  description = "Enables construction of an Openshift Cluster"
  type        = bool
  default     = true
}

variable "do_build_infrastructure" {
  description = "Enables deployment of the IPA Pre-Reqs and Crunchy Database"
  type        = bool
  default     = true
}

variable "do_deploy_ipa" {
  description = "Enables deployment of the IPA Helm Chart via Argo"
  type        = bool
  default     = true
}

variable "do_test_ipa" {
   description = "Launches the COD smoketest deployment of the IPA Helm Chart via Argo"
  type    = bool
  default = true
}

variable "enable_gpu_infrastructure" {
  description = "Enables construction of GPU Machinesets, Machines, ClusterAutoscaler"
  type        = bool
  default     = true
}

variable "enable_monitoring_infrastructure" {
  description = "Enables the deployment of the Indico Monitoring helm chart"
  type        = bool
  default     = true
}

variable "do_install_ipa_crds" {
  description = "Enables the deployment of the Indico CRDs helm chart"
  type        = bool
  default     = true
}

variable "use_openshift_admission_controller" {
  description = "Enables the deployment of the Openshift Admission Controller to support Crunchy PostGres Database creation"
  type        = bool
  default     = true
}
