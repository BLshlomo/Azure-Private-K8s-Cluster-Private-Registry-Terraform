
resource azurerm_container_registry private-registry {
  name                     = "shlomo"
  resource_group_name      = local.rg
  location                 = local.region
  sku                      = "Premium"
  admin_enabled            = true

  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action = "Allow"
      subnet_id = azurerm_subnet.kube-sub.id
    }
  }
}

resource azurerm_private_endpoint ep {
  name                = "private-endpoint"
  location            = local.region
  resource_group_name = local.rg
  subnet_id           = azurerm_subnet.kube-sub.id

  private_service_connection {
    name                           = "private-acr-connection"
    private_connection_resource_id = azurerm_container_registry.private-registry.id
    is_manual_connection           = false
    subresource_names = ["registry"]
  }
}

resource "azurerm_private_dns_zone" "acr-dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = local.rg
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke-ep-acr" {
  name                  = "spoke-ep-acr"
  resource_group_name   = local.rg
  private_dns_zone_name = azurerm_private_dns_zone.acr-dns.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}
