

resource "azuread_application" "openshift-application" {
  display_name = "${var.label}-${var.region}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "openshift" {
  application_id               = azuread_application.openshift-application.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "application-secret" {
  display_name          = "openshift-sp-secret"
  application_object_id = azuread_application.openshift-application.object_id
}

resource "azurerm_role_assignment" "virtual-network-assignment" {
  depends_on = [
    module.networking
  ]
  count                = length(var.roles)
  scope                = module.networking.vnet_id
  role_definition_name = var.roles[count.index].role
  principal_id         = azuread_service_principal.openshift.object_id
}

resource "azurerm_role_assignment" "resource-provider-assignment" {
  depends_on = [
    module.networking
  ]
  count                = length(var.roles)
  scope                = module.networking.vnet_id
  role_definition_name = var.roles[count.index].role
  principal_id         = data.azuread_service_principal.redhat-openshift.object_id
}

module "argo-registration" {
  depends_on = [
    module.cluster
  ]

  count = var.argo_enabled == true ? 1 : 0

  source                       = "app.terraform.io/indico/indico-argo-registration/mod"
  version                      = "1.1.12"
  cluster_name                 = var.label
  region                       = var.region
  argo_password                = var.argo_password
  argo_username                = var.argo_username
  account                      = var.account
  cloud_provider               = "azure"
  argo_github_team_admin_group = var.argo_github_team_owner
  endpoint                     = module.cluster.kubernetes_host
  ca_data                      = module.cluster.kubernetes_cluster_ca_certificate
}


resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_resource_group" "cod-cluster" {
  name     = local.resource_group_name
  location = var.region
}

module "networking" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source              = "app.terraform.io/indico/indico-azure-openshift-network/mod"
  version             = "1.0.1"
  label               = var.label
  vnet_cidr           = var.vnet_cidr
  subnet_cidrs        = var.subnet_cidrs
  worker_subnet_cidrs = var.worker_subnet_cidrs
  resource_group_name = local.resource_group_name
  region              = var.region
}

module "storage" {
  depends_on = [
    azurerm_resource_group.cod-cluster
  ]
  source              = "app.terraform.io/indico/indico-azure-blob/mod"
  version             = "0.1.9"
  label               = var.label
  region              = var.region
  resource_group_name = local.resource_group_name
}

module "cluster" {
  depends_on = [
    module.networking,
    azurerm_resource_group.cod-cluster
  ]
  source = "./modules/openshift-cluster"

  openshift-version   = var.openshift_version
  vault_path          = lower("${var.account}-${var.region}-${var.label}")
  vault_mount         = var.vault_mount_path
  subscriptionId      = split("/", data.azurerm_subscription.primary.id)[2]
  pull_secret         = var.openshift_pull_secret
  cluster_domain      = lower("${var.label}-${var.account}")
  label               = var.label
  region              = var.region
  svp_client_id       = azuread_service_principal.openshift.application_id
  svp_client_secret   = azuread_application_password.application-secret.value
  master_subnet_id    = module.networking.subnet_id
  worker_subnet_id    = module.networking.worker_subnet_id
  resource_group_name = local.resource_group_name

}


# Create the service account, cluster role + binding, which ArgoCD expects to be present in the targeted cluster
resource "kubernetes_service_account_v1" "terraform" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "terraform"
    namespace = "kube-system"
  }

  automount_service_account_token = true
  image_pull_secret {
    name = "harbor-pull-secret"
  }
}

resource "kubernetes_secret_v1" "terraform" {
  depends_on = [
    kubernetes_service_account_v1.terraform
  ]
  metadata {
    name      = "terraform"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.terraform.metadata.0.name
    }
  }
  type = "kubernetes.io/service-account-token"
}


resource "kubernetes_cluster_role" "terraform" {

  depends_on = [
    kubernetes_service_account_v1.terraform
  ]

  metadata {
    name = "terraform"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    non_resource_urls = ["*"]
    verbs             = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "terraform" {
  depends_on = [
    kubernetes_cluster_role.terraform
  ]

  metadata {
    name = "terraform"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.terraform.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.terraform.metadata.0.name
    namespace = kubernetes_service_account_v1.terraform.metadata.0.namespace
  }
}


data "kubernetes_secret_v1" "terraform" {
  depends_on = [
    kubernetes_secret_v1.terraform
  ]

  metadata {
    name      = "terraform"
    namespace = kubernetes_service_account_v1.terraform.metadata.0.namespace
  }
}


resource "vault_kv_secret_v2" "terraform-credentials" {
  depends_on = [
    data.kubernetes_secret_v1.terraform
  ]
  mount = var.vault_mount
  name  = "sa"
  data_json = jsonencode(
    {
      kubernetes_host                   = module.cluster.kubernetes_host
      kubernetes_client_certificate     = base64decode(data.kubernetes_secret_v1.terraform.data["service-ca.crt"])
      kubernetes_client_key             = data.kubernetes_secret_v1.terraform.data["token"]
      kubernetes_cluster_ca_certificate = base64decode(data.kubernetes_secret_v1.terraform.data["ca.crt"]),
      api_ip                            = module.cluster.openshift_api_server_ip
      console_ip                        = module.cluster.openshift_console_ip
    }
  )
}


data "kubernetes_resource" "infrastructure-cluster" {
  depends_on = [
    module.cluster
  ]
  api_version = "config.openshift.io/v1"
  kind        = "Infrastructure"

  metadata {
    name = "cluster"
  }
}

output "infrastructure_id" {
  value = local.infrastructure_id
}

