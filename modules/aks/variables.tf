variable location {
  type = string
}

variable resource_group {
  type = string
}

variable kube_sub {
  type = string
}

variable k8s_ver {
  type = string
}

variable dns_prefix {
  type = string
}

variable vm_size {
  type = string
}

variable node_count {
  type = string
}

variable min_node_count {
  type = string
}

variable max_node_count {
  type = string
}

variable cluster_admin_user {
  type = string
}

variable pub_key {
  type = string
}

variable docker_bridge_cidr {
  type = string
}

variable cni_dns_svc_ip {
  type = string
}

variable cni_svc_cidr {
  type = string
}

variable acr {
  type = string
}

variable depends {}
