

# add an A record for the api server
resource "azurerm_dns_a_record" "api-server" {
  count = var.use_private_console == true ? 1 : 0
  depends_on = [
    module.cluster
  ]
  name                = "api.${local.dns_name}"
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300
  records             = [module.cluster.api_server_ip]
}

# add an A record for the console
resource "azurerm_dns_a_record" "console" {
  count = var.use_private_console == true ? 1 : 0
  depends_on = [
    module.cluster
  ]
  name                = "*.apps.${local.dns_name}"
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = var.common_resource_group
  ttl                 = 300
  records             = [module.cluster.console_ingress_ip]
}

