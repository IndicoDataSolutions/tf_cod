terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
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
      version = "2.37.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    github = {
      source  = "integrations/github"
      version = "5.34.0"
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

  chart_version_parts = split("-", var.ipa_version)
  chart_suffix        = trimprefix(var.ipa_version, local.chart_version_parts[0])

  environment = var.load_environment == "" ? lower("${var.aws_account}-${var.region}-${var.label}") : lower(var.load_environment)
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
  count                         = var.direct_connect == false && var.network_module == "public_networking" ? 1 : 0
  source                        = "app.terraform.io/indico/indico-aws-network/mod"
  version                       = "1.2.3"
  label                         = var.label
  vpc_cidr                      = var.vpc_cidr
  private_subnet_cidrs          = var.private_subnet_cidrs
  public_subnet_cidrs           = var.public_subnet_cidrs
  subnet_az_zones               = var.subnet_az_zones
  region                        = var.region
  s3_endpoint_enabled           = var.s3_endpoint_enabled
  gateway_vpc_endpoints_enabled = var.gateway_vpc_endpoints_enabled
}


module "networking" {
  count                               = var.direct_connect == false && var.network_module == "networking" && var.load_environment == "" ? 1 : 0
  source                              = "app.terraform.io/indico/indico-aws-network/mod"
  version                             = "2.4.0"
  label                               = var.label
  vpc_cidr                            = var.vpc_cidr
  private_subnet_cidrs                = var.private_subnet_cidrs
  public_subnet_cidrs                 = var.public_subnet_cidrs
  subnet_az_zones                     = var.subnet_az_zones
  region                              = var.region
  allow_public                        = var.network_allow_public
  network_type                        = var.network_type
  load_vpc_id                         = var.load_vpc_id
  private_subnet_tag_name             = var.private_subnet_tag_name
  private_subnet_tag_value            = var.private_subnet_tag_value
  public_subnet_tag_name              = var.public_subnet_tag_name
  public_subnet_tag_value             = var.public_subnet_tag_value
  sg_tag_name                         = var.sg_tag_name
  sg_tag_value                        = var.sg_tag_value
  enable_vpc_flow_logs                = var.enable_vpc_flow_logs
  vpc_flow_logs_iam_role_arn          = var.vpc_flow_logs_iam_role_arn != "" ? var.vpc_flow_logs_iam_role_arn : var.enable_vpc_flow_logs ? local.environment_vpc_flow_logs_role_arn : ""
  enable_firewall                     = var.enable_firewall
  firewall_subnet_cidrs               = var.firewall_subnet_cidrs
  firewall_allow_list                 = var.firewall_allow_list
  s3_endpoint_enabled                 = var.s3_endpoint_enabled
  gateway_vpc_endpoints_enabled       = var.gateway_vpc_endpoints_enabled
  create_nginx_ingress_security_group = var.create_nginx_ingress_security_group
  nginx_ingress_allowed_cidrs         = var.nginx_ingress_allowed_cidrs
}

module "sqs_sns" {
  count                      = var.sqs_sns == true && var.load_environment == "" ? 1 : 0
  source                     = "app.terraform.io/indico/indico-aws-sqs-sns/mod"
  version                    = "2.0.2"
  region                     = var.region
  label                      = var.label
  kms_master_key_id          = local.environment_kms_key_key_id
  sqs_sns_type               = var.sqs_sns_type
  ipa_sns_topic_name         = var.ipa_sns_topic_name
  ipa_sqs_queue_name         = var.ipa_sqs_queue_name
  indico_sqs_sns_policy_name = var.indico_sqs_sns_policy_name
}

module "lambda-sns-forwarder" {
  count                = var.lambda_sns_forwarder_enabled == true && var.load_environment == "" ? 1 : 0
  source               = "app.terraform.io/indico/indico-lambda-sns-forwarder/mod"
  version              = "2.0.1"
  region               = var.region
  label                = var.label
  subnet_ids           = flatten([local.environment_private_subnet_ids])
  security_group_id    = var.network_module == "networking" ? local.environment_all_subnets_sg_id : module.security-group.all_subnets_sg_id
  kms_key              = local.environment_kms_key_arn
  sns_arn              = var.lambda_sns_forwarder_topic_arn == "" ? local.environment_indico_ipa_topic_arn : var.lambda_sns_forwarder_topic_arn
  destination_endpoint = var.lambda_sns_forwarder_destination_endpoint
  github_organization  = var.lambda_sns_forwarder_github_organization
  github_repository    = var.lambda_sns_forwarder_github_repository
  github_branch        = var.lambda_sns_forwarder_github_branch
  git_zip_path         = var.lambda_sns_forwarder_github_zip_path
  git_pat              = var.git_pat
  function_variables   = var.lambda_sns_forwarder_function_variables
}

module "kms_key" {
  count            = var.load_environment == "" ? 1 : 0
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
  vpc_id         = local.environment_indico_vpc_id
  network_module = var.network_module
}

module "s3-storage" {
  count                              = var.load_environment == "" ? 1 : 0
  source                             = "app.terraform.io/indico/indico-aws-buckets/mod"
  version                            = "4.5.0"
  force_destroy                      = true # allows terraform to destroy non-empty buckets.
  label                              = var.label
  kms_key_arn                        = local.environment_kms_key_arn
  submission_expiry                  = var.submission_expiry
  uploads_expiry                     = var.uploads_expiry
  include_rox                        = var.include_rox
  enable_backup                      = var.enable_s3_backup
  backup_role_arn                    = var.enable_s3_backup ? local.environment_s3_backup_role_arn : ""
  enable_access_logging              = var.enable_s3_access_logging
  bucket_type                        = var.bucket_type
  data_s3_bucket_name_override       = var.data_s3_bucket_name_override
  api_models_s3_bucket_name_override = var.api_models_s3_bucket_name_override
  pgbackup_s3_bucket_name_override   = var.pgbackup_s3_bucket_name_override
  miniobkp_s3_bucket_name_override   = var.miniobkp_s3_bucket_name_override
  include_miniobkp                   = var.include_miniobkp && var.insights_enabled ? true : false
  allowed_origins                    = ["https://${local.dns_name}"]
  loki_s3_bucket_name_override       = var.loki_s3_bucket_name_override
  enable_loki_logging                = var.enable_loki_logging
}


# This empties the buckets upon delete so terraform doesn't take forever.
resource "null_resource" "s3-delete-data-bucket" {
  count = var.load_environment == "" ? 1 : 0
  depends_on = [
    module.s3-storage
  ]

  triggers = {
    data_bucket_name = local.environment_data_s3_bucket_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm \"s3://${self.triggers.data_bucket_name}/\" --recursive --only-show-errors || echo \"WARNING: S3 rm ${self.triggers.data_bucket_name} reported errors\" >&2"
  }
}

resource "null_resource" "s3-delete-data-pgbackup-bucket" {
  count = var.include_pgbackup == true && var.load_environment == "" ? 1 : 0

  depends_on = [
    module.s3-storage
  ]

  triggers = {
    pg_backup_bucket_name = local.environment_pgbackup_s3_bucket_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm \"s3://${self.triggers.pg_backup_bucket_name}/\" --recursive --only-show-errors || echo \"WARNING: S3 rm ${self.triggers.pg_backup_bucket_name} reported errors\" >&2"
  }
}

module "efs-storage" {
  count              = var.include_efs == true && var.load_environment == "" ? 1 : 0
  source             = "app.terraform.io/indico/indico-aws-efs/mod"
  version            = "2.0.0"
  label              = var.efs_filesystem_name == "" ? var.label : var.efs_filesystem_name
  efs_type           = var.efs_type
  additional_tags    = merge(var.additional_tags, { "type" = "local-efs-storage" })
  security_groups    = var.network_module == "networking" ? [local.environment_all_subnets_sg_id] : [module.security-group.all_subnets_sg_id]
  private_subnet_ids = flatten([local.environment_private_subnet_ids])
  kms_key_arn        = local.environment_kms_key_arn

}

module "fsx-storage" {
  count                       = var.include_fsx == true && var.load_environment == "" ? 1 : 0
  source                      = "app.terraform.io/indico/indico-aws-fsx/mod"
  version                     = "2.0.0"
  label                       = var.label
  additional_tags             = var.additional_tags
  region                      = var.region
  storage_capacity            = var.storage_capacity
  subnet_id                   = local.environment_private_subnet_ids[0]
  security_group_id           = var.network_module == "networking" ? local.environment_all_subnets_sg_id : module.security-group.all_subnets_sg_id
  data_bucket                 = local.environment_data_s3_bucket_name
  api_models_bucket           = local.environment_api_models_s3_bucket_name
  kms_key                     = local.environment_kms_key_key
  per_unit_storage_throughput = var.per_unit_storage_throughput
  deployment_type             = var.fsx_deployment_type
  include_rox                 = var.include_rox
  fsx_type                    = var.fsx_type
  fsx_rwx_id                  = var.fsx_rwx_id
  fsx_rwx_subnet_ids          = var.fsx_rwx_subnet_ids
  fsx_rwx_security_group_ids  = var.fsx_rwx_security_group_ids
  fsx_rwx_dns_name            = var.fsx_rwx_dns_name
  fsx_rwx_mount_name          = var.fsx_rwx_mount_name
  fsx_rwx_arn                 = var.fsx_rwx_arn
  fsx_rox_id                  = var.fsx_rox_id
  fsx_rox_arn                 = var.fsx_rox_arn
}

module "iam" {
  count   = var.load_environment == "" ? 1 : 0
  source  = "app.terraform.io/indico/indico-aws-iam/mod"
  version = "0.0.14"

  # EKS node role
  create_node_role           = var.create_node_role
  eks_cluster_nodes_iam_role = var.node_role_name_override == null ? "${var.label}-${var.region}-node-role" : var.node_role_name_override
  label                      = var.label
  region                     = var.region
  cluster_node_policies      = var.cluster_node_policies
  aws_primary_dns_role_arn   = var.aws_primary_dns_role_arn
  efs_filesystem_id          = [var.include_efs == true ? local.environment_efs_filesystem_id : ""]
  fsx_arns                   = [var.include_rox ? local.environment_fsx_rox_arn : "", var.include_fsx == true ? local.environment_fsx_rwx_arn : ""]
  s3_buckets                 = compact([local.environment_data_s3_bucket_name, var.include_pgbackup ? local.environment_pgbackup_s3_bucket_name : "", var.include_rox ? local.environment_api_models_s3_bucket_name : "", lower("${var.aws_account}-aws-cod-snapshots"), var.performance_bucket ? "indico-locust-benchmark-test-results" : "", var.include_miniobkp && var.insights_enabled ? local.environment_miniobkp_s3_bucket_name : "", var.enable_loki_logging ? local.environment_loki_s3_bucket_name : ""])
  kms_key_arn                = local.environment_kms_key_arn
  # EKS cluster role
  create_cluster_iam_role = var.create_eks_cluster_role
  eks_cluster_iam_role    = var.eks_cluster_iam_role_name_override == null ? (var.create_eks_cluster_role ? "eks-cluster-${var.label}-${var.region}" : null) : var.eks_cluster_iam_role_name_override

  # s3 replication
  enable_s3_replication                            = var.enable_s3_replication
  create_s3_replication_role                       = var.create_s3_replication_role
  s3_replication_role_name                         = var.s3_replication_role_name_override == null ? "s3-bucket-replication-${var.label}" : var.s3_replication_role_name_override
  s3_replication_destination_kms_key_arn           = var.destination_kms_key_arn
  s3_replication_data_destination_bucket_name      = var.data_destination_bucket
  s3_replication_api_model_destination_bucket_name = var.api_model_destination_bucket
  # s3 backup
  create_s3_backup_role = var.create_s3_backup_role
  s3_backup_bucket_arn  = var.data_s3_bucket_name_override == null ? "indico-data-${var.label}" : var.data_s3_bucket_name_override
  s3_backup_role_name   = var.s3_backup_role_name_override
  # Iam flow logs role
  create_vpc_flow_logs_role = var.create_vpc_flow_logs_role
  vpc_flow_logs_role_name   = var.vpc_flow_logs_role_name_override
  #Karpenter
  karpenter_enabled = var.karpenter_enabled
  account_id        = data.aws_caller_identity.current.account_id
}

module "cluster" {
  source               = "app.terraform.io/indico/indico-aws-eks-cluster/mod"
  version              = "9.0.39"
  label                = var.label
  region               = var.region
  cluster_version      = var.k8s_version
  default_tags         = merge(coalesce(var.default_tags, {}), coalesce(var.additional_tags, {}))
  cluster_iam_role_arn = local.environment_cluster_role_arn == "null" ? null : local.environment_cluster_role_arn
  generate_kms_key     = var.create_eks_cluster_role ? false : true #Once the cluster is created, we cannot change the kms key.
  kms_key_arn          = local.environment_kms_key_arn

  vpc_id     = local.environment_indico_vpc_id
  az_count   = var.az_count
  subnet_ids = flatten([local.environment_private_subnet_ids])

  node_groups          = local.node_groups
  node_role_name       = local.environment_node_role_name
  node_role_arn        = local.environment_node_role_arn
  instance_volume_size = var.instance_volume_size
  instance_volume_type = var.instance_volume_type

  additional_users = var.additional_users

  public_endpoint_enabled  = var.cluster_api_endpoint_public == true ? true : false
  private_endpoint_enabled = var.network_allow_public == true ? false : true

  cluster_security_group_id             = local.environment_all_subnets_sg_id
  cluster_additional_security_group_ids = var.network_module == "networking" ? [local.environment_all_subnets_sg_id] : []
  http_tokens                           = var.http_tokens
}

resource "time_sleep" "wait_1_minutes_after_cluster" {
  depends_on = [module.cluster]

  create_duration = "1m"
}

locals {
  readapi_billing_variable             = var.environment == "production" ? var.prod_billing : var.dev_billing
  readapi_api_key_variable             = var.environment == "production" ? var.prod_apikey : var.dev_apikey
  readapi_computer_vision_variable     = var.environment == "production" ? var.prod_computer_vision_api_url : var.dev_computer_vision_api_url
  readapi_computer_vision_key_variable = var.environment == "production" ? var.prod_computer_vision_api_key : var.dev_computer_vision_api_key
  readapi_form_recognizer_variable     = var.environment == "production" ? var.prod_form_recognizer_api_url : var.dev_form_recognizer_api_url
  readapi_form_recognizer_key_variable = var.environment == "production" ? var.prod_form_recognizer_api_key : var.dev_form_recognizer_api_key
}


resource "kubernetes_secret" "readapi" {
  count = var.enable_readapi ? 1 : 0
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
  metadata {
    name = "readapi-secret"
  }

  data = {
    billing                       = local.readapi_billing_variable
    apikey                        = local.readapi_api_key_variable
    READAPI_COMPUTER_VISION_HOST  = local.readapi_computer_vision_variable
    READAPI_COMPUTER_VISION_KEY   = local.readapi_computer_vision_key_variable
    READAPI_FORM_RECOGNITION_HOST = local.readapi_form_recognizer_variable
    READAPI_FORM_RECOGNITION_KEY  = local.readapi_form_recognizer_key_variable
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
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = module.cluster.kubernetes_host
  cluster_ca_certificate = module.cluster.kubernetes_cluster_ca_certificate
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.label]
    command     = "aws"
  }
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
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
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
  security_group_id      = var.include_fsx == true ? tolist(local.environment_fsx_rwx_security_group_ids)[0] : ""
  cluster_name           = var.label
  dns_zone_name          = var.dns_zone_name == "" ? lower("${var.aws_account}.${var.domain_suffix}") : var.dns_zone_name
  calculated_domain_name = lower("${var.label}.${var.region}.${local.dns_zone_name}")
  dns_name               = var.domain_host == "" ? local.calculated_domain_name : var.domain_host
  monitoring_domain_name = var.load_environment == "" ? local.dns_name : local.calculated_domain_name
}


data "aws_route53_zone" "primary" {
  count    = var.use_static_ssl_certificates ? 0 : 1
  name     = var.is_alternate_account_domain == "false" ? local.dns_zone_name : lower(local.alternate_domain_root)
  provider = aws.dns-control
}


resource "aws_route53_record" "ipa-app-caa" {
  count   = var.is_alternate_account_domain == "true" || var.use_static_ssl_certificates || var.load_environment != "" ? 0 : 1
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
