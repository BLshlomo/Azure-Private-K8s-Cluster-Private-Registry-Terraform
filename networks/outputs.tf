output hub-subs {
  value = tolist(azurerm_virtual_network.hub.subnet) 
}

output kube-sub {
  value = azurerm_subnet.kube-sub
}
