output ssh-command {
  value = module.bastion.ssh-command
}

output bastion-ip {
  value = module.bastion.bastion-pip
}

output acr {
  value = module.registry.acr.login_server
}

output acr-ep {
  value = module.registry.acr-ep.private_dns_zone_configs
}

output cluster {
  value = module.aks.cluster
}
