resource azurerm_private_dns_zone acr-dns {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group
}

resource azurerm_private_dns_zone_virtual_network_link spoke-ep-acr {
  name                  = "spoke-ep-acr"
  resource_group_name   = var.resource_group
  private_dns_zone_name = azurerm_private_dns_zone.acr-dns.name
  virtual_network_id    = var.spoke_net
}

resource azurerm_container_registry private-acr {
  name                     = var.acr_name
  resource_group_name      = var.resource_group
  location                 = var.location
  sku                      = "Premium"
  admin_enabled            = true

  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action    = "Allow"
      subnet_id = var.kube_sub
    }
  }
}

resource azurerm_private_endpoint ep {
  name                = "kube2acr-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group
  subnet_id           = var.kube_sub

  private_service_connection {
    name                           = "private-kube2acr-connection"
    private_connection_resource_id = azurerm_container_registry.private-acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "private-acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr-dns.id]
  }
}
