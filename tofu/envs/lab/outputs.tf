output "guests" {
  description = "Mapa de todos os guests geridos: VMID e endereco."
  value = {
    opnsense = { id = module.opnsense.vm_id, ip = module.opnsense.ipv4_address }
    haos     = { id = module.haos.vm_id, ip = module.haos.ipv4_address }
    ocp_sno  = { id = module.ocp_sno.vm_id, ip = module.ocp_sno.ipv4_address }
    devbox   = { id = module.devbox.vm_id, ip = module.devbox.ipv4_address }
    bazzite  = { id = module.bazzite.vm_id, ip = module.bazzite.ipv4_address }
    kafka    = { id = module.kafka.vm_id, ip = module.kafka.ipv4_address }
    postgres = { id = module.postgres.vm_id, ip = module.postgres.ipv4_address }
    registry = { id = module.registry.vm_id, ip = module.registry.ipv4_address }
  }
}

output "memory_committed_gb" {
  description = "Memoria total declarada pelos guests. Comparar com 64 GB fisicos menos 6 GB de host."
  value       = (2048 + 4096 + 24576 + 16384 + 16384 + 4096 + 4096 + 2048) / 1024
}

output "network_mode" {
  description = "Fase de rede em vigor."
  value       = var.network_mode
}
