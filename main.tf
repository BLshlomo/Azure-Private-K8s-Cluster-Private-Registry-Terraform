
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
  region      = "UK South"
  rg          = azurerm_resource_group.rg.name
  #hub_subnets = tolist(azurerm_virtual_network.hub.subnet)
  #spoke_subnet = tolist(azurerm_virtual_network.spoke.subnet)[0].id
}

resource azurerm_resource_group rg {
  name     = "rg"
  location = local.region
}

#output test {
#value = local.hub_subnets[0]
#value = local.hub_subnets[index(local.hub_subnets[*].name, "AzureFirewallSubnet")].name
#value = tolist(azurerm_virtual_network.hub.subnet)[*].name
#value = tolist(azurerm_virtual_network.spoke.subnet)[0].id
#}

module networks {
  source         = "./networks"
  resource_group = local.rg
  location       = local.region
}

module firewall {
  source         = "./firewall"
  resource_group = local.rg
  location       = local.region
  subnet_id      = module.networks.hub-subs[index(module.networks.hub-subs[*].name, "AzureFirewallSubnet")].id
}

module routes {
  source         = "./routes"
  resource_group = local.rg
  location       = local.region
  ip_getway      = module.firewall.fw-private-ip
  kube_sub       = module.networks.kube-sub.id
}

#module aks {
#  source             = "./aks"
#  resource_group     = local.rg
#  location           = local.region
#  kube_sub           = module.networks.kube-sub.id
#  k8s_ver            = var.k8s_ver
#  dns_prefix         = var.dns_prefix
#  vm_size            = var.vm_size
#  min_node_count     = var.min_node_count
#  max_node_count     = var.max_node_count
#  node_count         = var.node_count
#  cluster_admin_user = var.cluster_admin_user
#  key_data           = file("~/.ssh/ted.pub")
#  docker_bridge_cidr = var.docker_bridge_cidr
#  cni_dns_svc_ip     = var.cni_dns_svc_ip
#  cni_svc_cidr       = var.cni_svc_cidr
#  acr                = module.registry.id
#  #depends            = module.routes
#  depends_on         = [module.routes]
#}
#
#resource azurerm_container_registry private-acr {
#  name                     = "abcdefgadevel"
#  resource_group_name      = local.rg
#  location                 = local.region
#  sku                      = "Premium"
#  admin_enabled            = true
#
#  network_rule_set {
#    default_action = "Deny"
#    virtual_network {
#      action = "Allow"
#      subnet_id = azurerm_subnet.kube-sub.id
#    }
#  }
#}
#
#resource azurerm_private_endpoint ep {
#  name                = "private-endpoint"
#  location            = local.region
#  resource_group_name = local.rg
#  subnet_id           = azurerm_subnet.kube-sub.id
#
#  private_service_connection {
#    name                           = "private-acr-connection"
#    private_connection_resource_id = azurerm_container_registry.private-acr.id
#    is_manual_connection           = false
#    subresource_names = ["registry"]
#  }
#
#  private_dns_zone_group {
#    name                 = "private-acr-dns-group"
#    private_dns_zone_ids = [azurerm_private_dns_zone.acr-dns.id]
#  }
#}
#
#resource "azurerm_private_dns_zone" "acr-dns" {
#  name                = "privatelink.azurecr.io"
#  resource_group_name = local.rg
#}
#
#resource "azurerm_private_dns_zone_virtual_network_link" "spoke-ep-acr" {
#  name                  = "spoke-ep-acr"
#  resource_group_name   = local.rg
#  private_dns_zone_name = azurerm_private_dns_zone.acr-dns.name
#  virtual_network_id    = azurerm_virtual_network.spoke.id
#}
#
#module bastion {
#  source         = "./bastion"
#  resource_group = local.rg
#  location       = local.region
#  username       = "localadmin"
#  pub_key        = file("~/.ssh/ted.pub")
#  priv_key       = file("~/.ssh/ted")
#  subnet_id      = local.hub_subnets[index(local.hub_subnets[*].name, "bastion")].id
#  vnet_id        = azurerm_virtual_network.hub.id
#}
#
#module vm {
#  source         = "./instance"
#  resource_group = local.rg
#  location       = local.region
#  username       = "localadmin"
#  key            = file("~/.ssh/ted.pub")
#  subnet_id      = azurerm_subnet.kube-sub.id
#  sg             = module.bastion.sg
#}
#
