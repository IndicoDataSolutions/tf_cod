variable "do_create_cluster" {
  type    = bool
  default = true
}

variable "do_build_infrastructure" {
  type    = bool
  default = true
}

variable "do_deploy_ipa" {
  type    = bool
  default = true
}

variable "do_test_ipa" {
  type    = bool
  default = true
}

variable "enable_gpu_infrastructure" {
  type    = bool
  default = true
}

variable "enable_monitoring_infrastructure" {
  type    = bool
  default = true
}

variable "do_install_ipa_crds" {
  type    = bool
  default = true
}

variable "use_openshift_admission_controller" {
  type    = bool
  default = true
}
