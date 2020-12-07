
terraform {
  backend gcs {
    bucket = "devel-tfstate"
    prefix = "terraform/state/azurem_sela"
  }
}

# Configure the Azure Provider
provider azurerm {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "~> 2.38"
  features {}
}

locals {
  version = "~> 2.0"
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

module registry {
  source         = "./registry"
  resource_group = local.rg
  location       = local.region
  kube_sub       = module.networks.kube-sub.id
  spoke_net      = module.networks.spoke-net.id
  acr_name       = "abcdefgadevel"
}

module aks {
  source             = "./aks"
  resource_group     = local.rg
  location           = local.region
  kube_sub           = module.networks.kube-sub.id
  k8s_ver            = var.k8s_ver
  dns_prefix         = var.dns_prefix
  vm_size            = var.vm_size
  min_node_count     = var.min_node_count
  max_node_count     = var.max_node_count
  node_count         = var.node_count
  cluster_admin_user = var.cluster_admin_user
  pub_key            = file("~/.ssh/ted.pub")
  docker_bridge_cidr = var.docker_bridge_cidr
  cni_dns_svc_ip     = var.cni_dns_svc_ip
  cni_svc_cidr       = var.cni_svc_cidr
  acr                = module.registry.acr.id
  depends            = module.routes
  #depends_on         = [module.routes]
}

module bastion {
  source         = "./bastion"
  resource_group = local.rg
  location       = local.region
  username       = "localadmin"
  pub_key        = file("~/.ssh/ted.pub")
  priv_key       = file("~/.ssh/ted")
  subnet_id      = module.networks.hub-subs[index(module.networks.hub-subs[*].name, "bastion")].id
  vnet_id        = module.networks.hub-net.id
  aks_dns_name   = join(".", slice(split(".", module.aks.cluster.private_fqdn), 1, length(split(".", module.aks.cluster.private_fqdn))))
  aks_dns_rg     = module.aks.cluster.node_resource_group
  kubeadmin      = module.aks.cluster.kube_admin_config_raw
}

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

output split {
  value = split(".", module.aks.cluster.private_fqdn)
}

output slice {
  value = slice(split(".", module.aks.cluster.private_fqdn), 1, length(split(".", module.aks.cluster.private_fqdn)))
}

output join {
  value = join(".", slice(split(".", module.aks.cluster.private_fqdn), 1, length(split(".", module.aks.cluster.private_fqdn))))
}
