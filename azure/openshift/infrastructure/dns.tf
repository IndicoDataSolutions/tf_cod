
resource "azurerm_dns_caa_record" "fqdn" {
  count               = var.enable_dns_infrastructure == true ? 1 : 0
  name                = var.dns_prefix
  zone_name           = data.azurerm_dns_zone.domain.0.name
  resource_group_name = var.common_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "sectigo.com"
  }
}
