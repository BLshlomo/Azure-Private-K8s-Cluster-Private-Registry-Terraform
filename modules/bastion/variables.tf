variable resource_group {
  type = string
}

variable location {
  type = string
}

variable pub_key {
  type        = string
}

variable priv_key {
  type        = string
}

variable username {
  type        = string
  default     = "azureuser"
}

variable vnet_id {
  description = "Bastion vnet id"
  type        = string
}

variable subnet_id {
  description = "Bastion subnet id"
  type        = string
}

variable aks_dns_name {
  description = "AKS DNS Zone name to link bastion vnet to"
  type        = string
}

variable aks_dns_rg {
  description = "AKS DNS Zone rg"
  type        = string
}

variable kubeadmin {}
