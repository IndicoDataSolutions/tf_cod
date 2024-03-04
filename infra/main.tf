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

  monitoring_enabled = var.monitoring_enabled
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
    github  = github
    helm    = helm
    kubectl = kubectl
    vault   = vault
  }

  aws_account = var.aws_account
  region      = var.region
  label       = var.label
  dns_name    = local.dns_name

  argo_enabled = var.argo_enabled
  argo_repo    = var.argo_repo
  argo_branch  = var.argo_branch
  argo_path    = var.argo_path
  message      = var.message

  harbor_pull_secret_b64 = var.harbor_pull_secret_b64
  vault_mount_path       = var.vault_mount_path

  ipa_repo                       = var.ipa_repo
  infra_crds_version             = var.infra_crds_version
  infra-crds-values-yaml-b64     = var.crds-values-yaml-b64
  infra_pre_reqs_version         = var.infra_pre_reqs_version
  infra-pre-reqs-values-yaml-b64 = var.pre-reqs-values-yaml-b64

  include_efs                 = var.include_efs
  efs_filesystem_id           = module.infra.efs_filesystem_id
  include_fsx                 = var.include_fsx
  security_group_id           = var.include_fsx == true ? tolist(module.infra.fsx-rwx.security_group_ids)[0] : ""
  fsx_rwx_subnet_id           = module.infra.fsx_storage_fsx_rwx_subnet_id
  local_registry_enabled      = var.local_registry_enabled
  use_static_ssl_certificates = var.use_static_ssl_certificates
  is_alternate_account_domain = var.is_alternate_account_domain
  aws_primary_dns_role_arn    = var.aws_primary_dns_role_arn
}

module "local-registry" {
  source = "../modules/common/local-registry"

  count = var.local_registry_enabled ? 1 : 0

  depends_on = [
    null_resource.stage_one,
    module.common_helm
  ]

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  aws_account            = var.aws_account
  argo_enabled           = var.argo_enabled
  ipa_repo               = var.ipa_repo
  local_registry_version = var.local_registry_version
  dns_name               = local.dns_name
  efs_filesystem_id      = module.infra.local_registry_efs_filesystem_id
  htpasswd_bcrypt        = htpasswd_password.hash.bcrypt
  general_password       = random_password.password.result
}

module "vault_secrets_operator" {
  source = "../modules/common/vault-secrets-operator-setup"

  depends_on = [
    null_resource.stage_one,
    module.common_helm
  ]

  providers = {
    kubernetes = kubernetes
    helm       = helm
    vault      = vault
  }

  vault_address            = var.vault_address
  account                  = var.aws_account
  region                   = var.region
  name                     = var.label
  kubernetes_host          = module.infra.kube_host
  external_secrets_version = var.external_secrets_version
}

module "monitoring" {
  source = "../modules/common/monitoring"

  count = var.monitoring_enabled ? 1 : 0

  depends_on = [
    null_resource.stage_one,
    module.vault_secrets_operator
  ]

  providers = {
    helm                   = helm
    kubectl                = kubectl
    kubectl.thanos-kubectl = kubectl.thanos-kubectl
    random                 = random
  }

  aws_account = var.aws_account
  region      = var.region
  label       = var.label

  ipa_repo                        = var.ipa_repo
  monitoring_version              = var.monitoring_version
  keda_version                    = var.keda_version
  opentelemetry-collector_version = var.opentelemetry-collector_version

  thanos_enabled = var.thanos_enabled
  argo_enabled   = var.argo_enabled
  vault_address  = var.vault_address

  alerting_enabled                   = var.alerting_enabled
  alerting_slack_enabled             = var.alerting_slack_enabled
  alerting_pagerduty_enabled         = var.alerting_pagerduty_enabled
  alerting_email_enabled             = var.alerting_email_enabled
  alerting_slack_token               = var.alerting_slack_token
  alerting_slack_channel             = var.alerting_slack_channel
  alerting_pagerduty_integration_key = var.alerting_pagerduty_integration_key
  alerting_email_from                = var.alerting_email_from
  alerting_email_to                  = var.alerting_email_to
  alerting_email_username            = var.alerting_email_username
  alerting_email_password            = var.alerting_email_password

  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name

  dns_name = local.dns_name
}

resource "null_resource" "stage_two" {
  depends_on = [
    module.aws_helm,
    module.common_helm,
    module.local-registry,
    module.vault_secrets_operator,
    module.monitoring,
  ]

  provisioner "local-exec" {
    command = "echo General Indico Cluster configuration complete, moving on to product deployment"
  }
}

module "argo_registration" {
  count = var.argo_enabled == true ? 1 : 0

  depends_on = [
    null_resource.stage_two,
  ]

  providers = {
    kubernetes = kubernetes,
    argocd     = argocd
  }

  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.2.1"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  argo_namespace               = var.argo_namespace
  argo_host                    = var.argo_host
  account                      = var.aws_account
  cloud_provider               = "aws"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.infra.kube_host
  ca_data                      = module.infra.kube_ca_certificate
  indico_dev_cluster           = var.aws_account == "Indico-Dev"
}

module "intake" {
  source = "../modules/common/intake"

  depends_on = [
    null_resource.stage_two,
    module.argo_registration
  ]

  providers = {
    argocd  = argocd
    github  = github
    helm    = helm
    kubectl = kubectl
    time    = time
  }

  dns_name    = local.dns_name
  aws_account = var.aws_account
  region      = var.region
  label       = var.label

  use_static_ssl_certificates = var.use_static_ssl_certificates
  ssl_static_secret_name      = var.ssl_static_secret_name
  is_alternate_account_domain = var.is_alternate_account_domain
  aws_primary_dns_role_arn    = var.aws_primary_dns_role_arn

  ipa_repo                 = var.ipa_repo
  argo_enabled             = var.argo_enabled
  argo_repo                = var.argo_repo
  argo_branch              = var.argo_branch
  argo_path                = var.argo_path
  message                  = var.message
  ipa_pre_reqs_version     = var.ipa_pre_reqs_version
  pre-reqs-values-yaml-b64 = var.pre-reqs-values-yaml-b64
  ipa_version              = var.ipa_version
  k8s_version              = var.k8s_version
  ipa_values               = var.ipa_values
  az_count                 = var.az_count
  key_arn                  = module.infra.kms_key_arn
  s3_role_id               = module.infra.s3_role_id
  pgbackup_s3_bucket_name  = module.infra.pgbackup_s3_bucket_name
  enable_waf               = var.enable_waf
  waf_arn                  = module.infra.wafv2_arn
  use_acm                  = var.use_acm
  acm_arn                  = module.infra.acm_arn
  kubernetes_host          = module.infra.kube_host
  indico_vpc_id            = module.infra.network.indico_vpc_id
  public_subnet_ids        = module.infra.network.public_subnet_ids
  argo_project_name        = module.argo_registration[0].argo_project_name
  local_registry_enabled   = var.local_registry_enabled
  on_prem_test             = var.on_prem_test
  include_efs              = var.include_efs
  efs_filesystem_id        = module.infra.efs_filesystem_id
  include_fsx              = var.include_fsx
  fsx_rwx                  = module.infra.fsx-rwx

  ipa_smoketest_values  = var.ipa_smoketest_values
  ipa_smoketest_repo    = var.ipa_smoketest_repo
  ipa_smoketest_version = var.ipa_smoketest_version
  ipa_smoketest_enabled = var.ipa_smoketest_enabled

  restore_snapshot_enabled = var.restore_snapshot_enabled
  restore_snapshot_name    = var.restore_snapshot_name
}

/*
module "applications" {
  source = "../modules/common/applications"

  depends_on = [
    null_resource.stage_two,
  ]

  providers = {
    kubernetes = kubernetes
    helm       = helm
    vault      = vault
  }

  vault_address            = var.vault_address
  account                  = var.aws_account
  region                   = var.region
  name                     = var.label
  kubernetes_host          = module.infra.kube_host
  external_secrets_version = var.external_secrets_version
}

module "terraform_smoketest" {
  source = "../modules/common/terraform_smoketest"

  depends_on = [
    null_resource.stage_two,
  ]

  providers = {
    kubernetes = kubernetes
    helm       = helm
    vault      = vault
  }

  vault_address            = var.vault_address
  account                  = var.aws_account
  region                   = var.region
  name                     = var.label
  kubernetes_host          = module.infra.kube_host
  external_secrets_version = var.external_secrets_version
}
*/
