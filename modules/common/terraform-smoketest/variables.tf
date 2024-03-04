# Cluster info
variable "aws_account" {
  type        = string
  description = "The Name of the AWS Acccount this cluster lives in"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region in which to launch the indico stack"
}

variable "label" {
  type        = string
  default     = "indico"
  description = "The unique string to be prepended to resources names"
}

# Helm variables
variable "ipa_repo" {
  type    = string
  default = "https://harbor.devops.indico.io/chartrepo/indico-charts"
}

variable "argo_enabled" {
  type    = bool
  default = true
}