variable sg {}

variable resource_group {
  type = string
}

variable location {
  type = string
}

variable key {
  type        = string
}
variable username {
  type        = string
  default     = "azureuser"
}

variable subnet_id {
  description = "ID of subnet where jumpbox VM will be installed"
  type        = string
}

#variable dns_zone_name {
#  description = "Private DNS Zone name to link jumpbox's vnet to"
#  type        = string
#}
#
#variable dns_zone_resource_group {
#  description = "Private DNS Zone resource group"
#  type        = string
#}
