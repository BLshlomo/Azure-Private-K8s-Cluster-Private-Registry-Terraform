
terraform {
  backend gcs {
    bucket = "devel-tfstate"
    prefix = "terraform/state/azurem_sela"
  }
}

# Configure the Azure Provider
provider azurerm {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.38.0"
  features {}
}

locals {
  region  = "UK South"
  rg = azurerm_resource_group.rg.name
  hub_subnets = tolist(azurerm_virtual_network.hub.subnet)
  #spoke_subnet = tolist(azurerm_virtual_network.spoke.subnet)[0].id
}

resource azurerm_resource_group rg {
  name     = "rg"
  location = local.region
}

resource azurerm_virtual_network hub {
  name                = "hub"
  location            = local.region
  resource_group_name = local.rg
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
  location            = local.region
  resource_group_name = local.rg
  address_space       = ["10.10.4.0/22"]

  tags = {
   name = "kubernetes - spoke"
  }
}

resource azurerm_subnet kube-sub {
  name                 = "k8s-subnet"
  resource_group_name  = local.rg
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.10.4.0/24"]

  enforce_private_link_service_network_policies = false
  enforce_private_link_endpoint_network_policies = true
  service_endpoints = ["Microsoft.ContainerRegistry"]
}

resource azurerm_subnet acr-sub {
  name                 = "registry-subnet"
  resource_group_name  = local.rg
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.10.5.0/24"]

  enforce_private_link_service_network_policies = true
}

resource azurerm_virtual_network_peering hub2spoke {
  name                      = "hub2kube"
  resource_group_name       = local.rg
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource azurerm_virtual_network_peering spoke2hub {
  name                      = "kube2hub"
  resource_group_name       = local.rg
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

#output test {
  #value = local.hub_subnets[0]
  #value = local.hub_subnets[index(local.hub_subnets[*].name, "AzureFirewallSubnet")].name
  #value = tolist(azurerm_virtual_network.hub.subnet)[*].name
  #value = tolist(azurerm_virtual_network.spoke.subnet)[0].id
#}

module firewall {
  source         = "./firewall"
  resource_group = local.rg
  location       = local.region
  subnet_id      = local.hub_subnets[index(local.hub_subnets[*].name, "AzureFirewallSubnet")].id
}

resource azurerm_route_table spoke-rt {
  name                = "spoke-rt"
  location            = local.region
  resource_group_name = local.rg

  route {
    name                   = "egress"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.firewall.fw_private_ip
  }
}

resource azurerm_subnet_route_table_association spoke-kube {
  subnet_id      = azurerm_subnet.kube-sub.id
  route_table_id = azurerm_route_table.spoke-rt.id
}

resource azurerm_subnet_route_table_association spoke-acr {
  subnet_id      = azurerm_subnet.acr-sub.id
  route_table_id = azurerm_route_table.spoke-rt.id
}

resource azurerm_kubernetes_cluster private-cluster {
  name                    = "k8s"
  location                = local.region
  kubernetes_version      = var.k8s_ver
  resource_group_name     = local.rg
  dns_prefix              = var.dns_prefix
  private_cluster_enabled = true

  default_node_pool {
    name           = "default"
    vm_size        = var.vm_size
    vnet_subnet_id = azurerm_subnet.kube-sub.id
    enable_auto_scaling = true
    type           = "VirtualMachineScaleSets"
    min_count      = var.min_node_count
    max_count      = var.max_node_count
    node_count     = var.node_count
  }

  role_based_access_control {
    enabled        = true
  }

  addon_profile {
    http_application_routing {
      enabled        = true
    }
  }

  linux_profile {
    admin_username = var.cluster_admin_user
    ssh_key {
      key_data     = file("~/.ssh/ted.pub")
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    docker_bridge_cidr = var.docker_bridge_cidr
    dns_service_ip     = var.cni_dns_svc_ip
    network_plugin     = "azure"
    outbound_type      = "userDefinedRouting"
    service_cidr       = var.cni_svc_cidr
  }

  depends_on = [azurerm_route_table.spoke-rt]
}

resource azurerm_role_assignment netcontributor {
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.kube-sub.id
  principal_id         = azurerm_kubernetes_cluster.private-cluster.identity[0].principal_id
}

resource azurerm_role_assignment acr-pull {
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.private-acr.id
  principal_id         = azurerm_kubernetes_cluster.private-cluster.identity[0].principal_id
}

resource azurerm_container_registry private-acr {
  name                     = "abcdefgadevel"
  resource_group_name      = local.rg
  location                 = local.region
  sku                      = "Premium"
  admin_enabled            = true

  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action = "Allow"
      subnet_id = azurerm_subnet.kube-sub.id
    }
  }
}

resource azurerm_private_endpoint ep {
  name                = "private-endpoint"
  location            = local.region
  resource_group_name = local.rg
  subnet_id           = azurerm_subnet.kube-sub.id

  private_service_connection {
    name                           = "private-acr-connection"
    private_connection_resource_id = azurerm_container_registry.private-acr.id
    is_manual_connection           = false
    subresource_names = ["registry"]
  }

  private_dns_zone_group {
    name                 = "private-acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr-dns.id]
  }
}

resource "azurerm_private_dns_zone" "acr-dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = local.rg
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke-ep-acr" {
  name                  = "spoke-ep-acr"
  resource_group_name   = local.rg
  private_dns_zone_name = azurerm_private_dns_zone.acr-dns.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

module bastion {
  source         = "./bastion"
  resource_group = local.rg
  location       = local.region
  username       = "localadmin"
  pub_key        = file("~/.ssh/ted.pub")
  priv_key       = file("~/.ssh/ted")
  subnet_id      = local.hub_subnets[index(local.hub_subnets[*].name, "bastion")].id
  vnet_id        = azurerm_virtual_network.hub.id
}

module vm {
  source         = "./instance"
  resource_group = local.rg
  location       = local.region
  username       = "localadmin"
  key            = file("~/.ssh/ted.pub")
  subnet_id      = azurerm_subnet.kube-sub.id
  sg             = module.bastion.sg
}

