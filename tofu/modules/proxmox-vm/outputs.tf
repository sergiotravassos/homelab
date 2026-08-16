output "vm_id" {
  description = "VMID atribuido."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Nome do guest."
  value       = proxmox_virtual_environment_vm.this.name
}

output "mac_address" {
  description = "MAC da primeira interface — util para reservas DHCP."
  value       = try(proxmox_virtual_environment_vm.this.network_device[0].mac_address, null)
}

output "ipv4_address" {
  description = "Endereco configurado por cloud-init."
  value       = var.ipv4_address
}
