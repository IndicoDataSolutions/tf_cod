data "azurerm_resource_group" "domain" {
  name = var.common_resource_group
}

data "azurerm_dns_zone" "domain" {
  name                = local.base_domain
  resource_group_name = data.azurerm_resource_group.domain.name
}

resource "azurerm_dns_caa_record" "fqdn" {
  name                = local.dns_prefix
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}

resource "azurerm_dns_zone" "child-zone" {
  count               = var.is_openshift == true ? 1 : 0
  name                = "${var.label}.${local.base_domain}"
  resource_group_name = data.azurerm_resource_group.domain.name
}


# create ns record for sub-zone in parent zone
resource "azurerm_dns_ns_record" "example" {
  count               = var.is_openshift == true ? 1 : 0
  name                = var.label
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_resource_group.domain.name
  ttl                 = 60
  records             = azurerm_dns_zone.child-zone.name_servers
}
