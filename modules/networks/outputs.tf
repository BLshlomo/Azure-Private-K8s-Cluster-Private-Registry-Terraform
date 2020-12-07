output hub-subs {
  value = tolist(azurerm_virtual_network.hub.subnet)
}

output kube-sub {
  value = azurerm_subnet.kube-sub
}

output spoke-net {
  value = azurerm_virtual_network.spoke
}

output hub-net {
  value = azurerm_virtual_network.hub
}
