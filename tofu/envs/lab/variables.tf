variable "node_name" {
  description = "Nome do no Proxmox."
  type        = string
  default     = "forge"
}

variable "datastore_id" {
  description = "Datastore ZFS onde vivem os discos dos guests."
  type        = string
  default     = "local-zfs"
}

variable "network_mode" {
  description = <<-EOT
    "flat" — fase 1: guests sem etiqueta na LAN de casa, antes do switch gerivel.
    "vlan" — fase 2: segmentacao 802.1Q completa.
    Ver docs/adr/0005-vlans-com-switch-gerivel.md
  EOT
  type        = string
  default     = "flat"

  validation {
    condition     = contains(["flat", "vlan"], var.network_mode)
    error_message = "network_mode tem de ser \"flat\" ou \"vlan\"."
  }
}

variable "ssh_public_keys" {
  description = "Chaves publicas injectadas em todos os guests com cloud-init."
  type        = list(string)
}

variable "username" {
  description = "Utilizador criado por cloud-init nos guests Linux."
  type        = string
  default     = "sergio"
}

variable "cpu_ccd0_cpus" {
  description = <<-EOT
    CPUs do host no CCD com 3D V-Cache, formato taskset.
    APURAR NO METAL antes de usar — ver docs/hardware.md#topologia-de-cpu.
    A associacao entre CCD e indice de CPU nao e garantida por contrato.
  EOT
  type        = string
  default     = "0-7,16-23"
}

variable "cpu_ccd1_cpus" {
  description = "CPUs do host no CCD de alta frequencia, formato taskset."
  type        = string
  default     = "8-15,24-31"
}

variable "debian_template" {
  description = "Template LXC usado pelos contentores de plataforma."
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst"
}

variable "fedora_template_vm_id" {
  description = "VMID do template Fedora cloud construido pelo Packer."
  type        = number
  default     = 9000
}

variable "ocp_iso_file_id" {
  description = "ISO do instalador agent-based do OpenShift. null enquanto nao existir."
  type        = string
  default     = null
}

variable "gpu_pci_id" {
  description = <<-EOT
    Endereco PCI da RX 9060 XT, apurado com 'lspci -nn' no host.
    null desliga o passthrough — util para arrancar a bazzite sem GPU e diagnosticar.
  EOT
  type        = string
  default     = null
}

variable "usb_controller_host" {
  description = "Endereco do controlador USB passado a bazzite (comandos)."
  type        = string
  default     = null
}

variable "zigbee_usb_host" {
  description = "Dongle Zigbee/Z-Wave passado ao Home Assistant."
  type        = string
  default     = null
}
