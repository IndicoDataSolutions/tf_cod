module "infra" {
  count  = var.create_infra == true ? 1 : 0
  source = "../modules/aws/infra"

  aws_account     = var.aws_account
  region          = var.region
  label           = var.label
  name            = var.name
  additional_tags = var.additional_tags
  default_tags = var.default_tags
  dns_name        = local.dns_name
  is_alternate_account_domain = var.is_alternate_account_domain
  domain_suffix   = var.domain_suffix
  domain_host     = var.domain_host

  direct_connect       = var.direct_connect
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  subnet_az_zones      = var.subnet_az_zones

  existing_kms_key = var.existing_kms_key

  sqs_sns = var.sqs_sns

  submission_expiry = var.submission_expiry
  uploads_expiry = var.uploads_expiry
  include_rox = var.include_rox
  include_pgbackup = var.include_pgbackup

  include_efs = var.include_efs
  include_fsx = var.include_fsx
  local_registry_enabled = var.local_registry_enabled
  storage_capacity = var.storage_capacity
  per_unit_storage_throughput = var.per_unit_storage_throughput

  k8s_version = var.k8s_version
  node_groups = var.node_groups
  az_count = var.az_count
  cluster_node_policies = var.cluster_node_policies
  eks_cluster_iam_role = var.eks_cluster_iam_role
  snapshot_id = var.snapshot_id
  performance_bucket = var.performance_bucket

  oidc_enabled = var.oidc_enabled

  enable_waf = var.enable_waf

  eks_addon_version_guardduty = var.eks_addon_version_guardduty

  aws_primary_dns_role_arn = var.aws_primary_dns_role_arn
}
