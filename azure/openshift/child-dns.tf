
resource "azurerm_dns_zone" "child-zone" {
  name                = local.dns_name
  resource_group_name = azurerm_resource_group.cod-cluster.name
}


# create ns record for sub-zone in parent zone
resource "azurerm_dns_ns_record" "example" {
  name                = var.label
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_resource_group.domain.name
  ttl                 = 60
  records             = azurerm_dns_zone.child-zone.name_servers
}
