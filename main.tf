terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14.0"
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
      version = ">= 2.11.0"
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
      version = "3.19.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.70"
    }
  }
}

provider "time" {}

provider "keycloak" {
  # these values are provided by the keycloak varset from terraform cloud
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
  region     = var.region
  default_tags {
    tags = var.default_tags
  }
}

provider "azurerm" {
  features {}
  alias           = "indicoio"
  client_id       = var.azure_indico_io_client_id
  client_secret   = var.azure_indico_io_client_secret
  subscription_id = var.azure_indico_io_subscription_id
  tenant_id       = var.azure_indico_io_tenant_id
}

data "vault_kv_secret_v2" "terraform-snowflake" {
  mount = var.terraform_vault_mount_path
  name  = "snowflake"
}

provider "snowflake" {
  role        = "ACCOUNTADMIN"
  username    = var.snowflake_username
  account     = var.snowflake_account
  region      = var.snowflake_region
  private_key = jsondecode(data.vault_kv_secret_v2.terraform-snowflake.data_json)["snowflake_private_key"]
}

data "aws_caller_identity" "current" {}

# define the networking module we're using locally
locals {
  network = var.direct_connect == true ? module.private_networking : module.public_networking
  aws_usernames = [
    "svc_jenkins",
    "terraform-sa"
  ]
  eks_users = {
    for user in local.aws_usernames : user => {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
      username = user
      groups   = ["system:masters"]
    }
  }

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

module "sqs_sns" {
  count   = var.sqs_sns == true ? 1 : 0
  source  = "app.terraform.io/indico/indico-aws-sqs-sns/mod"
  version = "1.1.2"
  region  = var.region
  label   = var.label
}

module "kms_key" {
  source           = "app.terraform.io/indico/indico-aws-kms/mod"
  version          = "2.0.2"
  label            = var.label
  additional_tags  = var.additional_tags
  existing_kms_key = var.existing_kms_key
}

module "security-group" {
  source   = "app.terraform.io/indico/indico-aws-security-group/mod"
  version  = "1.0.0"
  label    = var.label
  vpc_cidr = var.vpc_cidr
  vpc_id   = local.network[0].indico_vpc_id
}


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

module "fsx-storage" {
  count                       = var.include_fsx == true ? 1 : 0
  source                      = "app.terraform.io/indico/indico-aws-fsx/mod"
  version                     = "1.4.1"
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
  version                    = "8.0.20"
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
  multi_az                   = var.node_group_multi_az
  key_pair                   = aws_key_pair.kp.key_name
  snapshot_id                = var.snapshot_id
  default_tags               = var.default_tags
  s3_buckets                 = [module.s3-storage.data_s3_bucket_name, var.include_pgbackup ? module.s3-storage.pgbackup_s3_bucket_name : "", var.include_rox ? module.s3-storage.api_models_s3_bucket_name : "", lower("${var.aws_account}-aws-cod-snapshots"), var.performance_bucket ? "indico-locust-benchmark-test-results" : ""]
  cluster_version            = var.k8s_version
  efs_filesystem_id          = [var.include_efs == true ? module.efs-storage[0].efs_filesystem_id : ""]
  aws_primary_dns_role_arn   = var.aws_primary_dns_role_arn
}

module "readapi" {
  count = var.enable_readapi ? 1 : 0
  providers = {
    azurerm = azurerm.indicoio
  }
  source          = "app.terraform.io/indico/indico-azure-readapi/mod"
  version         = "2.1.2"
  readapi_name    = lower("${var.aws_account}-${var.label}")
  client_id       = var.azure_indico_io_client_id
  client_secret   = var.azure_indico_io_client_secret
  subscription_id = var.azure_indico_io_subscription_id
  tenant_id       = var.azure_indico_io_tenant_id
}

resource "kubernetes_secret" "readapi" {
  count      = var.enable_readapi ? 1 : 0
  depends_on = [module.cluster, module.readapi]
  metadata {
    name = "readapi-queue-auth"
  }

  data = {
    endpoint                   = module.readapi[0].endpoint
    access_key                 = module.readapi[0].access_key
    storage_account_name       = module.readapi[0].storage_account_name
    storage_account_id         = module.readapi[0].storage_account_id
    storage_account_access_key = module.readapi[0].storage_account_access_key
    storage_queue_name         = module.readapi[0].storage_queue_name
    storage_connection_string  = module.readapi[0].storage_connection_string
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

resource "aws_security_group" "indico_allow_access" {
  name        = "${var.label}-allow-access"
  description = "Promethues, Grafana"
  vpc_id      = local.network[0].indico_vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["35.174.218.89/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# argo 
provider "argocd" {
  server_addr = var.argo_host
  username    = var.argo_username
  password    = var.argo_password
}

provider "kubernetes" {
  host                   = "https://7659A97CCE79736090C07DE46A380D85.gr7.us-east-2.eks.amazonaws.com"
  cluster_ca_certificate = base64decode("LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXhOREUzTXpJd05Gb1hEVE15TVRJeE1URTNNekl3TkZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBS1JHCmtrbVRxcTVEZW9ZdUlkWmNtSXEvdnhORGtNMmRCU0NvcUlYMWF1Ti9scUlRV3R4ZmZRbzZqT3M2Y0RJQVJOQzIKWWN3N0wwcDlsRFB5VzNLQmJWbWFVK1pFRGJvZUhPcEdsWEtrOEpkL1JlWXpxeWJKakQvM2dQOXYya25LdkVBVgpWQ2x2aWNEMmR0SUFJMmtGbkFhcU9zc0JQZ0RvdWl6c242QmY1dHMvc3d4MTFNOGpHcVBHTW5xVHRrbFV3a0owCmNHNXRsZnBYVjRGVkJrZFBlVVR5QW9GeldUSmZrZFpYSllLOWhTVExIWEZDUExIL0tQSWZiaUNKS1Y3WFlMTTUKUjdiK1VGU0ZJZ0JJZm5laEc0Nzc0SkJCcGVQdGErTzhTUHZTSjdmRHV5dzM5ckFpc01VL0Z6QmVCR2JnVE1HbQo1bW1rbnJmdGZzMkJaRnlZeWhFQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZISGV5SkFTZS8xcDFQenRYSVE0aWtsYXFlMXJNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBSHhOOTI1TXo4M3J0QWxjMTBzTQovYTBEc1A5VTVHYkxQZlQrbXFMYTdsS2dpdGtINTBsRG0zS0dpenNNTDVFR0NraVUzM2s5UUJGRGYvd1NEWDRHCjh0eXNkeW5BOXI5VVg0aTYyb1h0Wk42WDZBT3RmWFpTN2NFYlJxSEtVTFFMM2pIU1ZOZzRUUlRiRW5sOHRERFAKT3ZUckJrcWpaNHJaMER3S2gzM0xvR3g2ZXc3ZGx2QkJrK0k1d3JiL0ordndRNTNTRUlMZEdMbHkyYmtsT1VkSwpkOVd2WUZzckw5dVRwWkZ0QTBRUldaMjRSWE0vekRWZ2xURUpKOVc4b05keEU0VFRZM0REUU9WU2xhYmk0RDlHCnpZYklLRlpOaTNIdVdsQUlKVmVad0NHTDBqTFNaaGRxZ3R3UnA2YnFQYjNxYVE1STY5T29WcC95cEdmZVhYak8KVnhnPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==")
  token                  = "k8s-aws-v1.aHR0cHM6Ly9zdHMudXMtZWFzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBWFdLUVhENUZPSUFIVzVOWCUyRjIwMjMxMDEyJTJGdXMtZWFzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyMzEwMTJUMTg0NzQ3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TaWduYXR1cmU9ZDQwNWUxZjBlYjQzMGVmY2Q4NGE2ODE2OWUwMjdjODZlNjNjMjc2ZjllNTNiOTk5YTJhOGIwMDg3M2NmYzU4Mg"
}

provider "kubectl" {
  host                   = "https://7659A97CCE79736090C07DE46A380D85.gr7.us-east-2.eks.amazonaws.com"
  cluster_ca_certificate = base64decode("LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXhOREUzTXpJd05Gb1hEVE15TVRJeE1URTNNekl3TkZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBS1JHCmtrbVRxcTVEZW9ZdUlkWmNtSXEvdnhORGtNMmRCU0NvcUlYMWF1Ti9scUlRV3R4ZmZRbzZqT3M2Y0RJQVJOQzIKWWN3N0wwcDlsRFB5VzNLQmJWbWFVK1pFRGJvZUhPcEdsWEtrOEpkL1JlWXpxeWJKakQvM2dQOXYya25LdkVBVgpWQ2x2aWNEMmR0SUFJMmtGbkFhcU9zc0JQZ0RvdWl6c242QmY1dHMvc3d4MTFNOGpHcVBHTW5xVHRrbFV3a0owCmNHNXRsZnBYVjRGVkJrZFBlVVR5QW9GeldUSmZrZFpYSllLOWhTVExIWEZDUExIL0tQSWZiaUNKS1Y3WFlMTTUKUjdiK1VGU0ZJZ0JJZm5laEc0Nzc0SkJCcGVQdGErTzhTUHZTSjdmRHV5dzM5ckFpc01VL0Z6QmVCR2JnVE1HbQo1bW1rbnJmdGZzMkJaRnlZeWhFQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZISGV5SkFTZS8xcDFQenRYSVE0aWtsYXFlMXJNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBSHhOOTI1TXo4M3J0QWxjMTBzTQovYTBEc1A5VTVHYkxQZlQrbXFMYTdsS2dpdGtINTBsRG0zS0dpenNNTDVFR0NraVUzM2s5UUJGRGYvd1NEWDRHCjh0eXNkeW5BOXI5VVg0aTYyb1h0Wk42WDZBT3RmWFpTN2NFYlJxSEtVTFFMM2pIU1ZOZzRUUlRiRW5sOHRERFAKT3ZUckJrcWpaNHJaMER3S2gzM0xvR3g2ZXc3ZGx2QkJrK0k1d3JiL0ordndRNTNTRUlMZEdMbHkyYmtsT1VkSwpkOVd2WUZzckw5dVRwWkZ0QTBRUldaMjRSWE0vekRWZ2xURUpKOVc4b05keEU0VFRZM0REUU9WU2xhYmk0RDlHCnpZYklLRlpOaTNIdVdsQUlKVmVad0NHTDBqTFNaaGRxZ3R3UnA2YnFQYjNxYVE1STY5T29WcC95cEdmZVhYak8KVnhnPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==")
  token                  = "k8s-aws-v1.aHR0cHM6Ly9zdHMudXMtZWFzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBWFdLUVhENUZPSUFIVzVOWCUyRjIwMjMxMDEyJTJGdXMtZWFzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyMzEwMTJUMTg0NzQ3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TaWduYXR1cmU9ZDQwNWUxZjBlYjQzMGVmY2Q4NGE2ODE2OWUwMjdjODZlNjNjMjc2ZjllNTNiOTk5YTJhOGIwMDg3M2NmYzU4Mg"
}


provider "helm" {
  debug = true
  kubernetes {
    host                   = "https://7659A97CCE79736090C07DE46A380D85.gr7.us-east-2.eks.amazonaws.com"
    cluster_ca_certificate = base64decode("LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXhOREUzTXpJd05Gb1hEVE15TVRJeE1URTNNekl3TkZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBS1JHCmtrbVRxcTVEZW9ZdUlkWmNtSXEvdnhORGtNMmRCU0NvcUlYMWF1Ti9scUlRV3R4ZmZRbzZqT3M2Y0RJQVJOQzIKWWN3N0wwcDlsRFB5VzNLQmJWbWFVK1pFRGJvZUhPcEdsWEtrOEpkL1JlWXpxeWJKakQvM2dQOXYya25LdkVBVgpWQ2x2aWNEMmR0SUFJMmtGbkFhcU9zc0JQZ0RvdWl6c242QmY1dHMvc3d4MTFNOGpHcVBHTW5xVHRrbFV3a0owCmNHNXRsZnBYVjRGVkJrZFBlVVR5QW9GeldUSmZrZFpYSllLOWhTVExIWEZDUExIL0tQSWZiaUNKS1Y3WFlMTTUKUjdiK1VGU0ZJZ0JJZm5laEc0Nzc0SkJCcGVQdGErTzhTUHZTSjdmRHV5dzM5ckFpc01VL0Z6QmVCR2JnVE1HbQo1bW1rbnJmdGZzMkJaRnlZeWhFQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZISGV5SkFTZS8xcDFQenRYSVE0aWtsYXFlMXJNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBSHhOOTI1TXo4M3J0QWxjMTBzTQovYTBEc1A5VTVHYkxQZlQrbXFMYTdsS2dpdGtINTBsRG0zS0dpenNNTDVFR0NraVUzM2s5UUJGRGYvd1NEWDRHCjh0eXNkeW5BOXI5VVg0aTYyb1h0Wk42WDZBT3RmWFpTN2NFYlJxSEtVTFFMM2pIU1ZOZzRUUlRiRW5sOHRERFAKT3ZUckJrcWpaNHJaMER3S2gzM0xvR3g2ZXc3ZGx2QkJrK0k1d3JiL0ordndRNTNTRUlMZEdMbHkyYmtsT1VkSwpkOVd2WUZzckw5dVRwWkZ0QTBRUldaMjRSWE0vekRWZ2xURUpKOVc4b05keEU0VFRZM0REUU9WU2xhYmk0RDlHCnpZYklLRlpOaTNIdVdsQUlKVmVad0NHTDBqTFNaaGRxZ3R3UnA2YnFQYjNxYVE1STY5T29WcC95cEdmZVhYak8KVnhnPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==")
    token                  = "k8s-aws-v1.aHR0cHM6Ly9zdHMudXMtZWFzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBWFdLUVhENUZPSUFIVzVOWCUyRjIwMjMxMDEyJTJGdXMtZWFzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyMzEwMTJUMTg0NzQ3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TaWduYXR1cmU9ZDQwNWUxZjBlYjQzMGVmY2Q4NGE2ODE2OWUwMjdjODZlNjNjMjc2ZjllNTNiOTk5YTJhOGIwMDg3M2NmYzU4Mg"
  }
}

module "argo-registration" {
  depends_on = [
    module.cluster
  ]

  providers = {
    kubernetes = kubernetes,
    argocd     = argocd
  }
  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.1.16"
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

}

locals {
  security_group_id = var.include_fsx == true ? tolist(module.fsx-storage[0].fsx-rwx.security_group_ids)[0] : ""
  cluster_name      = var.label
  dns_name          = var.domain_host == "" ? lower("${var.label}.${var.region}.${var.aws_account}.indico.io") : var.domain_host
  #dns_suffix        = lower("${var.region}.${var.aws_account}.indico.io")
}


data "aws_route53_zone" "primary" {
  name = lower("${var.aws_account}.indico.io")
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
}


