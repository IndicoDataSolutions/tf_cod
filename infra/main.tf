module "infra" {
  source = "../modules/aws/infra"

  providers = {
    aws             = aws
    aws.dns-control = aws.dns-control
    kubernetes      = kubernetes
  }

  aws_account                 = var.aws_account
  region                      = var.region
  label                       = var.label
  name                        = var.name
  additional_tags             = var.additional_tags
  default_tags                = var.default_tags
  dns_name                    = local.dns_name
  is_alternate_account_domain = var.is_alternate_account_domain
  domain_suffix               = var.domain_suffix
  domain_host                 = var.domain_host

  direct_connect       = var.direct_connect
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  subnet_az_zones      = var.subnet_az_zones

  existing_kms_key = var.existing_kms_key

  sqs_sns = var.sqs_sns

  submission_expiry = var.submission_expiry
  uploads_expiry    = var.uploads_expiry
  include_rox       = var.include_rox
  include_pgbackup  = var.include_pgbackup

  include_efs                 = var.include_efs
  include_fsx                 = var.include_fsx
  local_registry_enabled      = var.local_registry_enabled
  storage_capacity            = var.storage_capacity
  per_unit_storage_throughput = var.per_unit_storage_throughput

  k8s_version           = var.k8s_version
  node_groups           = var.node_groups
  az_count              = var.az_count
  cluster_node_policies = var.cluster_node_policies
  eks_cluster_iam_role  = var.eks_cluster_iam_role
  snapshot_id           = var.snapshot_id
  performance_bucket    = var.performance_bucket

  oidc_enabled = var.oidc_enabled

  enable_waf = var.enable_waf

  eks_addon_version_guardduty = var.eks_addon_version_guardduty

  aws_primary_dns_role_arn = var.aws_primary_dns_role_arn
}

resource "null_resource" "stage_one" {
  depends_on = [module.infra]

  provisioner "local-exec" {
    command = "echo Infrastructure Creation complete, moving on to general charts"
  }
}

module "aws_helm" {
  source = "../modules/aws/helm"

  depends_on = [null_resource.stage_one]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  dns_name                    = local.dns_name
  k8s_dashboard_chart_version = var.k8s_dashboard_chart_version
  ipa_repo                    = var.ipa_repo
  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name
}

module "common_helm" {
  source = "../modules/common/infra"

  depends_on = [null_resource.stage_one]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  harbor_pull_secret_b64 = var.harbor_pull_secret_b64
  vault_mount_path       = var.vault_mount_path
  argo_enabled           = var.argo_enabled
  argo_branch            = var.argo_branch
  argo_path              = var.argo_path
  message                = var.message
  ipa_repo               = var.ipa_repo
  infra_crds_version     = var.infra_crds_version
  crds-values-yaml-b64   = var.crds-values-yaml-b64
}
/*
module "local-registry" {
  source = "../modules/aws/helm"

  depends_on = [null_resource.stage_one]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  dns_name                    = local.dns_name
  k8s_dashboard_chart_version = var.k8s_dashboard_chart_version
  ipa_repo                    = var.ipa_repo
  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name
}

module "monitoring" {
  source = "../modules/aws/helm"

  depends_on = [null_resource.stage_one]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  dns_name                    = local.dns_name
  k8s_dashboard_chart_version = var.k8s_dashboard_chart_version
  ipa_repo                    = var.ipa_repo
  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name
}

module "vault_secrets_operator" {
  source = "../modules/aws/helm"

  depends_on = [null_resource.stage_one]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  dns_name                    = local.dns_name
  k8s_dashboard_chart_version = var.k8s_dashboard_chart_version
  ipa_repo                    = var.ipa_repo
  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name
}

resource "null_resource" "stage_one" {
  depends_on = [
    module.aws_helm,
    module.common_helm,
    module.local-registry,
    module.monitoring,
    module.vault_secrets_operator
  ]

  provisioner "local-exec" {
    command = "echo General Indico Cluster configuration complete, moving on to product deployment and testing"
  }
}

*/
