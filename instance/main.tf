resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "ip-conf"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.4.10" 
  }
}

resource "azurerm_network_interface_security_group_association" "sg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = var.sg
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm"
  location                        = var.location
  resource_group_name             = var.resource_group
  network_interface_ids           = [azurerm_network_interface.nic.id]
  size                            = "Standard_DS1_v2"
  disable_password_authentication = true
  admin_username                  = var.username

  admin_ssh_key {
    username   = var.username
    public_key = var.key #file("~/.ssh/id_rsa.pub")
  }

  os_disk {
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
