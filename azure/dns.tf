data "azurerm_resource_group" "domain" {
  name = var.common_resource_group
}

data "azurerm_dns_zone" "domain" {
  count               = var.private_dns_zone == true ? 0 : 1
  name                = local.base_domain
  resource_group_name = data.azurerm_resource_group.domain.name
}

# Public DNS record
resource "azurerm_dns_caa_record" "fqdn" {
  count               = var.is_alternate_account_domain == "true" || var.private_dns_zone == true ? 0 : 1
  name                = local.dns_prefix
  zone_name           = data.azurerm_dns_zone.domain.0.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}
