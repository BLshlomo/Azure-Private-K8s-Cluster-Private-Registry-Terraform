# Initialize backend on GCP.
terraform {
  backend gcs {
    bucket = "devel-tfstate"
    prefix = "terraform/state/azurem_sela"
  }
}

# Configure the Azure provider.
provider azurerm {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "~> 2.38"
  features {}
}

# Set aliases.
locals {
  version = "~> 2.0"
  region      = "UK South"
  rg          = azurerm_resource_group.rg.name
}

# Create Azure resource group.
resource azurerm_resource_group rg {
  name     = "rg"
  location = local.region
}

# Create 2 virtual networks, one private (spoke) and one with public access (hub), used as as a getway and nat egress (firewall).
# The networks are connected by peering.
module networks {
  source         = "./modules/networks"
  resource_group = local.rg
  location       = local.region
}

# Firewall used as a nat getway, all egress allowed, no ingress.
module firewall {
  source         = "./modules/firewall"
  resource_group = local.rg
  location       = local.region
  subnet_id      = module.networks.hub-subs[index(module.networks.hub-subs[*].name, "AzureFirewallSubnet")].id
}

# Route all egress trafiic to the firewall.
module routes {
  source         = "./modules/routes"
  resource_group = local.rg
  location       = local.region
  ip_getway      = module.firewall.fw-private-ip
  kube_sub       = module.networks.kube-sub.id
}

# Set up a private image registry on Azure, no public access is allowed.
# Create endpoint on the private (Kubernetes) subnet, allow access only through that ep.
module registry {
  source         = "./modules/registry"
  resource_group = local.rg
  location       = local.region
  kube_sub       = module.networks.kube-sub.id
  spoke_net      = module.networks.spoke-net.id
  acr_name       = "shlomo"
}

# Create private Kubernetes cluster on a private subnet, kube, contains the image registry endpoint, and linked to the firewall (nat) on another vnet.
module aks {
  source             = "./modules/aks"
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
}

# Create an instance used on a public subnet, connect the subnet to the cluster private dns zone, used for the kubectl utility to manage kubernetes.
# Automatically upload the kubeadmin kubeconfig credentials to the instance once the cluster provides them.
module bastion {
  source         = "./modules/bastion"
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
