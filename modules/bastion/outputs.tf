output sg {
  value = azurerm_network_security_group.bastion_sg.id
}

output bastion-pip {
  value = azurerm_linux_virtual_machine.bastion.public_ip_address
}

output bastion-priv-ip {
  value = azurerm_linux_virtual_machine.bastion.public_ip_address
}

output ssh-command {
  value = "ssh ${var.username}@${azurerm_linux_virtual_machine.bastion.public_ip_address}"
}
