resource "azurerm_resource_group" "domain" {
  name     = var.common_resource_group
  location = var.region
}

data "azurerm_dns_zone" "domain" {
  name                = var.domain_suffix
  resource_group_name = azurerm_resource_group.domain.name
}

resource "azurerm_dns_caa_record" "example" {
  name                = "${var.label}.${var.region}.${var.domain_suffix}"
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = local.resource_group_name
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}

