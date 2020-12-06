resource azurerm_public_ip pip {
  name                = "public-ip"
  resource_group_name = var.resource_group
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource azurerm_firewall fw {
  name                = "firewall"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                 = "firewall-ip"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource azurerm_firewall_network_rule_collection egress {
  name                = "allow-egress"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group
  priority            = 100
  action              = "Allow"

  rule {
    name = "allow-all-egress"

    source_addresses = ["*"]

    destination_ports = ["*"]

    destination_addresses = ["*"]

    protocols = ["Any"]
  }
}

output fw-private-ip {
  value = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}
