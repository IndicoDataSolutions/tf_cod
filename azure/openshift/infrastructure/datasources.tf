data "azurerm_resource_group" "domain" {
  count = var.enable_dns_infrastructure == true ? 1 : 0
  name  = var.common_resource_group
}

data "azurerm_dns_zone" "domain" {
  count               = var.enable_dns_infrastructure == true ? 1 : 0
  name                = var.base_domain
  resource_group_name = data.azurerm_resource_group.domain.0.name
}


data "kubernetes_resource" "package" {
  api_version = "packages.operators.coreos.com/v1"
  kind        = "PackageManifest"

  metadata {
    name      = "gpu-operator-certified"
    namespace = "openshift-marketplace"
  }
}


data "kubernetes_resource" "infrastructure-cluster" {
  api_version = "config.openshift.io/v1"
  kind        = "Infrastructure"

  metadata {
    name = "cluster"
  }
}

