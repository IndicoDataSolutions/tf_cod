
locals {
  argo_app_name           = lower("${var.aws_account}.${var.region}.${var.label}-ipa")
  argo_smoketest_app_name = lower("${var.aws_account}.${var.region}.${var.label}-smoketest")
  argo_cluster_name       = "${var.aws_account}.${var.region}.${var.label}"
}

module "readapi_queue" {
  count = var.enable_readapi ? 1 : 0
  providers = {
    azurerm = azurerm.readapi
  }
  source       = "app.terraform.io/indico/indico-azure-readapi-queue/mod"
  version      = "1.0.0"
  readapi_name = lower("${var.aws_account}-${var.label}-s")
}

locals {
  readapi_secret_path = var.environment == "production" ? "prod-readapi" : "dev-readapi"
}

data "vault_kv_secret_v2" "readapi_secret" {
  mount = "customer-${var.aws_account}"
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
    storage_account_name          = module.readapi_queue[0].storage_account_name
    storage_account_id            = module.readapi_queue[0].storage_account_id
    storage_account_access_key    = module.readapi_queue[0].storage_account_access_key
    storage_queue_name            = module.readapi_queue[0].storage_queue_name
    QUEUE_CONNECTION_STRING       = module.readapi_queue[0].storage_connection_string
  }
}

module "snowflake" {
  count                 = var.enable_weather_station == true ? 1 : 0
  version               = "2.2.0"
  source                = "app.terraform.io/indico/indico-aws-snowflake/mod"
  label                 = var.label
  additional_tags       = var.additional_tags
  snowflake_db_name     = var.snowflake_db_name
  kms_key_arn           = module.kms_key.key_arn
  s3_bucket_name        = module.s3-storage.data_s3_bucket_name
  snowflake_private_key = jsondecode(data.vault_kv_secret_v2.terraform-snowflake.data_json)["snowflake_private_key"]
  snowflake_account     = var.snowflake_account
  snowflake_username    = var.snowflake_username
  region                = var.region
  aws_account_name      = var.aws_account
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
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = module.cluster.kubernetes_cluster_ca_certificate
  indico_dev_cluster           = var.aws_account == "Indico-Dev"
}
