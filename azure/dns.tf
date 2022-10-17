data "azurerm_resource_group" "domain" {
  name = var.common_resource_group
}

data "azurerm_dns_zone" "domain" {
  name                = var.domain_suffix
  resource_group_name = data.azurerm_resource_group.domain.name
}

resource "azurerm_dns_caa_record" "fqdn" {
  name                = "${var.label}-${var.region}.${var.domain_suffix}"
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}

