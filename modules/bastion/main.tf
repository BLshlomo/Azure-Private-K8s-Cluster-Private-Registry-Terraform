provider null {
  version = "~> 3.0"
}

provider template {
  version = "~> 2.2"
}

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
  name                  = "bastion-nic"
  location              = var.location
  resource_group_name   = var.resource_group
  enable_ip_forwarding  = true
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
  custom_data    = base64encode(data.template_file.linux-vm-cloud-init.rendered)

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
}

data template_file linux-vm-cloud-init {
  template = <<EOT
#!/bin/bash
mkdir -p /home/${var.username}/.kube
chown ${var.username}: /home/${var.username}/.kube
echo "init script" >> /home/localadmin/myINIT.txt
apt-get update && apt-get install -y apt-transport-https gnupg2
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
EOT
}

resource null_resource kubeadmin {
  triggers = {
   #kubeadmin = file("${path.root}/conf/kubeadmin")
    kubeadmin = var.kubeadmin
  }

  provisioner "file" {
    content     = self.triggers.kubeadmin
    destination = "~/.kube/config/"

    connection {
      host        = azurerm_linux_virtual_machine.bastion.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = var.priv_key
      timeout     = "10m"
    }
  }

  depends_on = [azurerm_linux_virtual_machine.bastion]
}

resource azurerm_private_dns_zone_virtual_network_link hub2aks-dns-link {
  name                  = "hub2aks-dns-link"
  resource_group_name   = var.aks_dns_rg
  private_dns_zone_name = var.aks_dns_name
  virtual_network_id    = var.vnet_id
}

