resource azurerm_route_table spoke-rt {
  name                = "spoke-rt"
  location            = var.location
  resource_group_name = var.resource_group

  route {
    name                   = "egress"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.ip_getway
  }
}

resource azurerm_subnet_route_table_association spoke-kube {
  subnet_id      = var.kube_sub
  route_table_id = azurerm_route_table.spoke-rt.id
}
