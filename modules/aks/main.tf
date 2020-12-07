resource azurerm_kubernetes_cluster private-cluster {
  name                    = "k8s"
  location                = var.location
  kubernetes_version      = var.k8s_ver
  resource_group_name     = var.resource_group
  dns_prefix              = var.dns_prefix
  private_cluster_enabled = true

  default_node_pool {
    name                = "default"
    vm_size             = var.vm_size
    vnet_subnet_id      = var.kube_sub
    enable_auto_scaling = true
    type                = "VirtualMachineScaleSets"
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    node_count          = var.node_count
  }

  role_based_access_control {
    enabled        = true
    azure_active_directory {
      managed = true
    }
  }

  addon_profile {
    http_application_routing {
      enabled        = true
    }
  }

  linux_profile {
    admin_username = var.cluster_admin_user
    ssh_key {
      key_data     = var.pub_key
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

  depends_on = [var.depends]
}

resource azurerm_role_assignment netcontributor {
  role_definition_name = "Network Contributor"
  scope                = var.kube_sub
  principal_id         = azurerm_kubernetes_cluster.private-cluster.identity[0].principal_id
}

resource azurerm_role_assignment acr-pull {
  role_definition_name = "AcrPull"
  scope                = var.acr
  principal_id         = azurerm_kubernetes_cluster.private-cluster.identity[0].principal_id
}
