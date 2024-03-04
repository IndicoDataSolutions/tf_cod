data "aws_caller_identity" "current" {}

# Private Key for Cluster Manager (TODO:remove)
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = var.name
  public_key = tls_private_key.pk.public_key_openssh
}

# Networking
module "public_networking" {
  count                = var.direct_connect == true ? 0 : 1
  source               = "app.terraform.io/indico/indico-aws-network/mod"
  version              = "1.2.0"
  label                = var.label
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  subnet_az_zones      = var.subnet_az_zones
}

module "private_networking" {
  count                = var.direct_connect == true ? 1 : 0
  source               = "app.terraform.io/indico/indico-aws-dc-network/mod"
  version              = "1.0.0"
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  subnet_az_zones      = var.subnet_az_zones
}

module "security-group" {
  source   = "app.terraform.io/indico/indico-aws-security-group/mod"
  version  = "1.0.0"
  label    = var.label
  vpc_cidr = var.vpc_cidr
  vpc_id   = local.network[0].indico_vpc_id
}

# KMS for Encryption
module "kms_key" {
  source           = "app.terraform.io/indico/indico-aws-kms/mod"
  version          = "2.1.0"
  label            = var.label
  additional_tags  = var.additional_tags
  existing_kms_key = var.existing_kms_key
}

# SQS/SNS
module "sqs_sns" {
  count             = var.sqs_sns == true ? 1 : 0
  source            = "app.terraform.io/indico/indico-aws-sqs-sns/mod"
  version           = "1.2.0"
  region            = var.region
  label             = var.label
  kms_master_key_id = module.kms_key.key.id
}

# Storage
module "s3-storage" {
  source            = "app.terraform.io/indico/indico-aws-buckets/mod"
  version           = "2.0.3"
  force_destroy     = true # allows terraform to destroy non-empty buckets.
  label             = var.label
  kms_key_arn       = module.kms_key.key.arn
  submission_expiry = var.submission_expiry
  uploads_expiry    = var.uploads_expiry
  include_rox       = var.include_rox
}


# This empties the buckets upon delete so terraform doesn't take forever.
resource "null_resource" "s3-delete-data-bucket" {
  depends_on = [
    module.s3-storage
  ]

  triggers = {
    data_bucket_name = module.s3-storage.data_s3_bucket_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm \"s3://${self.triggers.data_bucket_name}/\" --recursive --only-show-errors || echo \"WARNING: S3 rm ${self.triggers.data_bucket_name} reported errors\" >&2"
  }
}

resource "null_resource" "s3-delete-data-pgbackup-bucket" {
  count = var.include_pgbackup == true ? 1 : 0

  depends_on = [
    module.s3-storage
  ]

  triggers = {
    pg_backup_bucket_name = module.s3-storage.pgbackup_s3_bucket_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm \"s3://${self.triggers.pg_backup_bucket_name}/\" --recursive --only-show-errors || echo \"WARNING: S3 rm ${self.triggers.pg_backup_bucket_name} reported errors\" >&2"
  }
}

module "efs-storage" {
  count              = var.include_efs == true ? 1 : 0
  source             = "app.terraform.io/indico/indico-aws-efs/mod"
  version            = "0.0.1"
  label              = var.label
  additional_tags    = merge(var.additional_tags, { "type" = "local-efs-storage" })
  security_groups    = [module.security-group.all_subnets_sg_id]
  private_subnet_ids = flatten([local.network[0].private_subnet_ids])
  kms_key_arn        = module.kms_key.key_arn
}

module "efs-storage-local-registry" {
  count              = var.local_registry_enabled == true ? 1 : 0
  source             = "app.terraform.io/indico/indico-aws-efs/mod"
  version            = "0.0.1"
  label              = "${var.label}-local-registry"
  additional_tags    = merge(var.additional_tags, { "type" = "local-efs-storage-local-registry" })
  security_groups    = [module.security-group.all_subnets_sg_id]
  private_subnet_ids = flatten([local.network[0].private_subnet_ids])
  kms_key_arn        = module.kms_key.key_arn
}

module "fsx-storage" {
  count                       = var.include_fsx == true ? 1 : 0
  source                      = "app.terraform.io/indico/indico-aws-fsx/mod"
  version                     = "1.4.2"
  label                       = var.label
  additional_tags             = var.additional_tags
  region                      = var.region
  storage_capacity            = var.storage_capacity
  subnet_id                   = local.network[0].private_subnet_ids[0]
  security_group_id           = module.security-group.all_subnets_sg_id
  data_bucket                 = module.s3-storage.data_s3_bucket_name
  api_models_bucket           = module.s3-storage.api_models_s3_bucket_name
  kms_key                     = module.kms_key.key
  per_unit_storage_throughput = var.per_unit_storage_throughput
  include_rox                 = var.include_rox
}

module "cluster" {
  cod_snapshots_enabled      = true
  allow_dns_management       = true
  aws_account_name           = var.aws_account
  oidc_enabled               = false
  source                     = "app.terraform.io/indico/indico-aws-eks-cluster/mod"
  version                    = "8.1.7"
  label                      = var.label
  additional_tags            = var.additional_tags
  region                     = var.region
  map_users                  = values(local.eks_users)
  vpc_id                     = local.network[0].indico_vpc_id
  security_group_id          = module.security-group.all_subnets_sg_id
  subnet_ids                 = flatten([local.network[0].private_subnet_ids])
  node_groups                = var.node_groups
  cluster_node_policies      = var.cluster_node_policies
  eks_cluster_iam_role       = var.eks_cluster_iam_role
  eks_cluster_nodes_iam_role = "${var.label}-${var.region}-node-role"
  fsx_arns                   = [var.include_rox ? module.fsx-storage[0].fsx-rox.arn : "", var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.arn : ""]
  kms_key_arn                = module.kms_key.key_arn
  az_count                   = var.az_count
  key_pair                   = aws_key_pair.kp.key_name
  snapshot_id                = var.snapshot_id
  default_tags               = var.default_tags
  s3_buckets                 = [module.s3-storage.data_s3_bucket_name, var.include_pgbackup ? module.s3-storage.pgbackup_s3_bucket_name : "", var.include_rox ? module.s3-storage.api_models_s3_bucket_name : "", lower("${var.aws_account}-aws-cod-snapshots"), var.performance_bucket ? "indico-locust-benchmark-test-results" : ""]
  cluster_version            = var.k8s_version
  efs_filesystem_id          = [var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""]
  aws_primary_dns_role_arn   = var.aws_primary_dns_role_arn
}

# Alternate Domain name
data "aws_route53_zone" "primary" {
  name     = var.is_alternate_account_domain == "false" ? lower("${var.aws_account}.${var.domain_suffix}") : lower(local.alternate_domain_root)
  provider = aws.dns-control
}

resource "aws_route53_record" "ipa-app-caa" {
  count   = var.is_alternate_account_domain == "true" ? 0 : 1
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.dns_name
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"amazon.com\"",
    "0 issue \"amazonaws.com\"",
    "0 issue \"awstrust.com\""
  ]
  provider = aws.dns-control
}
