variable k8s_ver {
  default = "1.19.3"
}

variable dns_prefix {
  default = "k8s"
}

variable vm_size {
  default = "Standard_D2_v2"
}

variable node_count {
  default = "1"
}

variable min_node_count {
  default = "1"
}

variable max_node_count {
  default = "3"
}

variable cluster_admin_user {
  default = "k8sadmin"
}

#variable pub_key {
#  default     = file("~/.ssh/ted.pub")
#}

variable docker_bridge_cidr {
  default = "172.17.0.1/16"
}

variable cni_dns_svc_ip {
  default = "10.2.0.10"
}

variable cni_svc_cidr {
  default = "10.2.0.0/24"
}
