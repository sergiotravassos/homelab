output "vm_id" {
  value       = proxmox_virtual_environment_container.this.vm_id
  description = "VMID atribuido."
}

output "name" {
  value       = var.name
  description = "Nome do contentor."
}

output "ipv4_address" {
  value       = var.ipv4_address
  description = "Endereco configurado."
}
