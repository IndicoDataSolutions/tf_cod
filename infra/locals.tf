# Generating all of our values from the variables

locals {
  dns_name = var.domain_host == "" ? lower("${var.label}.${var.region}.${var.aws_account}.${var.domain_suffix}") : var.domain_host
}
