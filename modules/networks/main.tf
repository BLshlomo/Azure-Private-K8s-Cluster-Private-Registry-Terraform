resource azurerm_virtual_network hub {
  name                = "hub"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["10.0.0.0/22"]

  subnet {
    name           = "AzureFirewallSubnet"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "bastion"
    address_prefix = "10.0.2.0/24"
  }

  tags = {
   name = "hub"
  }
}

resource azurerm_virtual_network spoke {
  name                = "spoke"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["10.10.4.0/22"]

  tags = {
   name = "kubernetes - spoke"
  }
}

resource azurerm_subnet kube-sub {
  name                 = "k8s-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.10.4.0/24"]

  enforce_private_link_service_network_policies = false
  enforce_private_link_endpoint_network_policies = true
  service_endpoints = ["Microsoft.ContainerRegistry"]
}

resource azurerm_subnet acr-sub {
  name                 = "registry-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.10.5.0/24"]

  enforce_private_link_service_network_policies = true
}

resource azurerm_virtual_network_peering hub2spoke {
  name                      = "hub2kube"
  resource_group_name       = var.resource_group
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource azurerm_virtual_network_peering spoke2hub {
  name                      = "kube2hub"
  resource_group_name       = var.resource_group
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}
