resource azurerm_public_ip ip {
  name                = "bastion-ip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
}

resource azurerm_network_security_group bastion_sg {
  name                = "bastion-sg"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource azurerm_network_interface bastion_nic {
  name                = "bastion-nic"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "ip-conf"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}

resource azurerm_network_interface_security_group_association sg_association {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.bastion_sg.id
}

resource azurerm_linux_virtual_machine bastion {
  name                            = "bastion"
  location                        = var.location
  resource_group_name             = var.resource_group
  network_interface_ids           = [azurerm_network_interface.bastion_nic.id]
  size                            = "Standard_DS1_v2"
  disable_password_authentication = true
  admin_username                  = var.username

  admin_ssh_key {
    username   = var.username
    public_key = var.pub_key #file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "bastion-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "remote-exec" {
    connection {
      host     = self.public_ip_address
      type     = "ssh"
      user     = var.username
      private_key = var.priv_key
    }

    inline = [
      "sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y kubectl",
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    ]
  }
}

#resource azurerm_private_dns_zone_virtual_network_link hub-dns-link {
#  name                  = "hub-dns-link"
#  resource_group_name   = var.dns_zone_resource_group
#  private_dns_zone_name = var.dns_zone_name
#  virtual_network_id    = var.vnet_id
#}

output sg {
  value = azurerm_network_security_group.bastion_sg.id
}
