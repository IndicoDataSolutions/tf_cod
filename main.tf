terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.3.1"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5.1"
    }
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.22.0"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "1.0.4"
    }
  }
}

provider "time" {}

provider "keycloak" {
  initial_login = false
}

provider "vault" {
  address          = var.vault_address
  skip_child_token = true
  auth_login_userpass {
    username = var.vault_username
    password = var.vault_password
  }
}


provider "github" {
  token = var.git_pat
  owner = "IndicoDataSolutions"
}

provider "random" {}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
  region     = var.region
  default_tags {
    tags = var.default_tags
  }
}


provider "aws" {
  access_key = var.is_alternate_account_domain == "true" ? var.indico_aws_access_key_id : var.aws_access_key
  secret_key = var.is_alternate_account_domain == "true" ? var.indico_aws_secret_access_key : var.aws_secret_key
  token      = var.is_alternate_account_domain == "true" ? var.indico_aws_session_token : var.aws_session_token
  region     = var.region
  alias      = "dns-control"
  default_tags {
    tags = var.default_tags
  }
}

provider "htpasswd" {}

data "aws_caller_identity" "current" {}

# define the networking module we're using locally
locals {
  network = var.network_module == "public_networking" ? module.public_networking : module.networking

  argo_app_name           = lower("${var.aws_account}.${var.region}.${var.label}-ipa")
  argo_smoketest_app_name = lower("${var.aws_account}.${var.region}.${var.label}-smoketest")
  argo_cluster_name       = "${var.aws_account}.${var.region}.${var.label}"
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = var.name
  public_key = tls_private_key.pk.public_key_openssh
}

module "public_networking" {
  count                = var.direct_connect == false && var.network_module == "public_networking" ? 1 : 0
  source               = "app.terraform.io/indico/indico-aws-network/mod"
  version              = "1.2.2"
  label                = var.label
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  subnet_az_zones      = var.subnet_az_zones
  region               = var.region
  s3_endpoint_enabled  = var.s3_endpoint_enabled
}

module "networking" {
  count                      = var.direct_connect == false && var.network_module == "networking" ? 1 : 0
  source                     = "app.terraform.io/indico/indico-aws-network/mod"
  version                    = "2.1.0"
  label                      = var.label
  vpc_cidr                   = var.vpc_cidr
  private_subnet_cidrs       = var.private_subnet_cidrs
  public_subnet_cidrs        = var.public_subnet_cidrs
  subnet_az_zones            = var.subnet_az_zones
  region                     = var.region
  allow_public               = var.network_allow_public
  network_type               = var.network_type
  load_vpc_id                = var.load_vpc_id
  private_subnet_tag_name    = var.private_subnet_tag_name
  private_subnet_tag_value   = var.private_subnet_tag_value
  public_subnet_tag_name     = var.public_subnet_tag_name
  public_subnet_tag_value    = var.public_subnet_tag_value
  sg_tag_name                = var.sg_tag_name
  sg_tag_value               = var.sg_tag_value
  enable_vpc_flow_logs       = var.enable_vpc_flow_logs
  vpc_flow_logs_iam_role_arn = var.vpc_flow_logs_iam_role_arn
}

module "sqs_sns" {
  count             = var.sqs_sns == true ? 1 : 0
  source            = "app.terraform.io/indico/indico-aws-sqs-sns/mod"
  version           = "1.2.0"
  region            = var.region
  label             = var.label
  kms_master_key_id = module.kms_key.key.id
}

module "lambda-sns-forwarder" {
  count                = var.lambda_sns_forwarder_enabled == true ? 1 : 0
  source               = "app.terraform.io/indico/indico-lambda-sns-forwarder/mod"
  version              = "2.0.0"
  region               = var.region
  label                = var.label
  subnet_ids           = flatten([local.network[0].private_subnet_ids])
  security_group_id    = var.network_module == "networking" ? module.networking.all_subnets_sg_id : module.security-group.all_subnets_sg_id
  kms_key              = module.kms_key.key_arn
  sns_arn              = var.lambda_sns_forwarder_topic_arn == "" ? module.sqs_sns[0].indico_ipa_topic_arn : var.lambda_sns_forwarder_topic_arn
  destination_endpoint = var.lambda_sns_forwarder_destination_endpoint
  github_organization  = var.lambda_sns_forwarder_github_organization
  github_repository    = var.lambda_sns_forwarder_github_repository
  github_branch        = var.lambda_sns_forwarder_github_branch
  git_zip_path         = var.lambda_sns_forwarder_github_zip_path
  git_pat              = var.git_pat
  function_variables   = var.lambda_sns_forwarder_function_variables
}

module "kms_key" {
  source           = "app.terraform.io/indico/indico-aws-kms/mod"
  version          = "2.1.2"
  label            = var.label
  additional_tags  = var.additional_tags
  existing_kms_key = var.existing_kms_key
}

module "security-group" {
  source         = "app.terraform.io/indico/indico-aws-security-group/mod"
  version        = "3.0.0"
  label          = var.label
  vpc_cidr       = var.vpc_cidr
  vpc_id         = local.network[0].indico_vpc_id
  network_module = var.network_module
}


module "s3-storage" {
  source                = "app.terraform.io/indico/indico-aws-buckets/mod"
  version               = "3.3.1"
  force_destroy         = true # allows terraform to destroy non-empty buckets.
  label                 = var.label
  kms_key_arn           = module.kms_key.key.arn
  submission_expiry     = var.submission_expiry
  uploads_expiry        = var.uploads_expiry
  include_rox           = var.include_rox
  enable_backup         = var.enable_s3_backup
  enable_access_logging = var.enable_s3_access_logging
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
  security_groups    = var.network_module == "networking" ? [local.network[0].all_subnets_sg_id] : [module.security-group.all_subnets_sg_id]
  private_subnet_ids = flatten([local.network[0].private_subnet_ids])
  kms_key_arn        = module.kms_key.key_arn

}


module "efs-storage-local-registry" {
  count              = var.local_registry_enabled == true ? 1 : 0
  source             = "app.terraform.io/indico/indico-aws-efs/mod"
  version            = "0.0.1"
  label              = "${var.label}-local-registry"
  additional_tags    = merge(var.additional_tags, { "type" = "local-efs-storage-local-registry" })
  security_groups    = var.network_module == "networking" ? [local.network[0].all_subnets_sg_id] : [module.security-group.all_subnets_sg_id]
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
  security_group_id           = var.network_module == "networking" ? local.network[0].all_subnets_sg_id : module.security-group.all_subnets_sg_id
  data_bucket                 = module.s3-storage.data_s3_bucket_name
  api_models_bucket           = module.s3-storage.api_models_s3_bucket_name
  kms_key                     = module.kms_key.key
  per_unit_storage_throughput = var.per_unit_storage_throughput
  include_rox                 = var.include_rox
}

module "cluster" {
  cod_snapshots_enabled                 = true
  allow_dns_management                  = true
  aws_account_name                      = var.aws_account
  oidc_enabled                          = false
  source                                = "app.terraform.io/indico/indico-aws-eks-cluster/mod"
  version                               = "9.0.19"
  label                                 = var.label
  additional_tags                       = var.additional_tags
  region                                = var.region
  additional_users                      = var.additional_users
  vpc_id                                = local.network[0].indico_vpc_id
  security_group_id                     = var.network_module == "networking" ? local.network[0].all_subnets_sg_id : module.security-group.all_subnets_sg_id
  cluster_additional_security_group_ids = var.network_module == "networking" ? [local.network[0].all_subnets_sg_id] : []
  subnet_ids                            = flatten([local.network[0].private_subnet_ids])
  node_groups                           = var.node_groups
  cluster_node_policies                 = var.cluster_node_policies
  eks_cluster_iam_role                  = var.eks_cluster_iam_role
  eks_cluster_nodes_iam_role            = "${var.label}-${var.region}-node-role"
  fsx_arns                              = [var.include_rox ? module.fsx-storage[0].fsx-rox.arn : "", var.include_fsx == true ? module.fsx-storage[0].fsx-rwx.arn : ""]
  kms_key_arn                           = module.kms_key.key_arn
  az_count                              = var.az_count
  key_pair                              = aws_key_pair.kp.key_name
  snapshot_id                           = var.snapshot_id
  default_tags                          = var.default_tags
  s3_buckets                            = [module.s3-storage.data_s3_bucket_name, var.include_pgbackup ? module.s3-storage.pgbackup_s3_bucket_name : "", var.include_rox ? module.s3-storage.api_models_s3_bucket_name : "", lower("${var.aws_account}-aws-cod-snapshots"), var.performance_bucket ? "indico-locust-benchmark-test-results" : ""]
  cluster_version                       = var.k8s_version
  efs_filesystem_id                     = [var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""]
  aws_primary_dns_role_arn              = var.aws_primary_dns_role_arn
  private_endpoint_enabled              = var.network_allow_public == true ? false : true
  public_endpoint_enabled               = var.cluster_api_endpoint_public == true ? true : false
  instance_volume_size                  = var.instance_volume_size
  instance_volume_type                  = var.instance_volume_type
}

locals {
  readapi_secret_path = var.environment == "production" ? "prod-readapi" : "dev-readapi"
}

data "vault_kv_secret_v2" "readapi_secret" {
  mount = var.readapi_customer != null ? "customer-${var.readapi_customer}" : "customer-${var.aws_account}"
  name  = local.readapi_secret_path
}

resource "kubernetes_secret" "readapi" {
  count      = var.enable_readapi ? 1 : 0
  depends_on = [module.cluster]
  metadata {
    name = "readapi-secret"
  }

  data = {
    billing                       = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_url"]
    apikey                        = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_key"]
    READAPI_COMPUTER_VISION_HOST  = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_url"]
    READAPI_COMPUTER_VISION_KEY   = data.vault_kv_secret_v2.readapi_secret.data["computer_vision_api_key"]
    READAPI_FORM_RECOGNITION_HOST = data.vault_kv_secret_v2.readapi_secret.data["form_recognizer_api_url"]
    READAPI_FORM_RECOGNITION_KEY  = data.vault_kv_secret_v2.readapi_secret.data["form_recognizer_api_key"]
  }
}

# argo
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host                   = module.cluster.kubernetes_host
  cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  #token                  = module.cluster.kubernetes_token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = module.cluster.kubernetes_host
  cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  #token                  = module.cluster.kubernetes_token
  load_config_file = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}


provider "aws" {
  access_key = var.thanos_enabled == true ? var.indico_devops_aws_access_key_id : var.aws_access_key
  secret_key = var.thanos_enabled == true ? var.indico_devops_aws_secret_access_key : var.aws_secret_key
  token      = var.thanos_enabled == true ? var.indico_devops_aws_session_token : var.aws_session_token
  region     = var.indico_devops_aws_region
  alias      = "aws-indico-devops"
}

data "aws_eks_cluster" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

data "aws_eks_cluster_auth" "thanos" {
  count    = var.thanos_enabled == true ? 1 : 0
  name     = var.thanos_cluster_name
  provider = aws.aws-indico-devops
}

provider "kubectl" {
  alias                  = "thanos-kubectl"
  host                   = var.thanos_enabled == true ? data.aws_eks_cluster.thanos[0].endpoint : ""
  cluster_ca_certificate = var.thanos_enabled == true ? base64decode(data.aws_eks_cluster.thanos[0].certificate_authority[0].data) : ""
  token                  = var.thanos_enabled == true ? data.aws_eks_cluster_auth.thanos[0].token : ""
  load_config_file       = false
}

provider "helm" {
  debug = true
  kubernetes {
    host                   = module.cluster.kubernetes_host
    cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
    #token                  = module.cluster.kubernetes_token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.label]
      command     = "aws"
    }
  }
}

module "argo-registration" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    module.cluster
  ]

  providers = {
    kubernetes = kubernetes,
    argocd     = argocd
  }

  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.3.0"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  argo_namespace               = var.argo_namespace
  argo_host                    = var.argo_host
  account                      = var.aws_account
  cloud_provider               = "aws"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = module.cluster.kubernetes_cluster_ca_certificate
  indico_dev_cluster           = var.aws_account == "Indico-Dev"
}

locals {
  security_group_id = var.include_fsx == true ? tolist(module.fsx-storage[0].fsx-rwx.security_group_ids)[0] : ""
  cluster_name      = var.label
  dns_zone_name     = var.dns_zone_name == "" ? lower("${var.aws_account}.${var.domain_suffix}") : var.dns_zone_name
  dns_name          = var.domain_host == "" ? lower("${var.label}.${var.region}.${local.dns_zone_name}") : var.domain_host
}


data "aws_route53_zone" "primary" {
  count    = var.use_static_ssl_certificates ? 0 : 1
  name     = var.is_alternate_account_domain == "false" ? local.dns_zone_name : lower(local.alternate_domain_root)
  provider = aws.dns-control
}


resource "aws_route53_record" "ipa-app-caa" {
  count   = var.is_alternate_account_domain == "true" || var.use_static_ssl_certificates ? 0 : 1
  zone_id = data.aws_route53_zone.primary[0].zone_id
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
