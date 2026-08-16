variable "name" {
  description = "Nome do guest. Minusculas, sem sufixo de ambiente — ha um so ambiente."
  type        = string
}

variable "vm_id" {
  description = "VMID fixo. Atribuido por gama em locals.tf do ambiente."
  type        = number
}

variable "node_name" {
  description = "Nome do no Proxmox."
  type        = string
}

variable "description" {
  description = "Descricao visivel na interface. Deve dizer de onde vem o guest."
  type        = string
  default     = "Gerido por OpenTofu — nao editar na interface web"
}

variable "tags" {
  description = "Etiquetas do Proxmox, usadas para filtrar na interface."
  type        = list(string)
  default     = []
}

# ---------- CPU ----------
variable "cores" {
  description = "vCPU atribuidos."
  type        = number
}

variable "cpu_affinity" {
  description = <<-EOT
    Conjunto de CPUs do host onde este guest pode correr, no formato taskset
    (ex.: "0-7,16-23"). Deriva da topologia de CCD apurada no metal — ver
    docs/hardware.md. Vazio significa sem pinning.
  EOT
  type        = string
  default     = ""
}

variable "cpu_type" {
  description = "Modelo de CPU exposto ao guest. 'host' expoe todas as instrucoes."
  type        = string
  default     = "host"
}

# ---------- Memoria ----------
variable "memory_mb" {
  description = "Memoria dedicada, em MB."
  type        = number
}

variable "memory_floating_mb" {
  description = <<-EOT
    Minimo do ballooning, em MB. 0 desliga o ballooning — obrigatorio para o
    ocp-sno (que lida mal com memoria a desaparecer) e para a bazzite (hugepages).
  EOT
  type        = number
  default     = 0
}

variable "hugepages" {
  description = "Tamanho das hugepages ('2' ou '1024') ou null para desligar."
  type        = string
  default     = null

  validation {
    condition     = var.hugepages == null || contains(["2", "1024"], coalesce(var.hugepages, "x"))
    error_message = "hugepages tem de ser \"2\", \"1024\" ou null."
  }
}

# ---------- Disco ----------
variable "disk_size_gb" {
  description = "Tamanho do disco principal, em GB."
  type        = number
}

variable "datastore_id" {
  description = "Datastore do Proxmox onde vive o disco."
  type        = string
  default     = "local-zfs"
}

# ---------- Rede ----------
variable "vlan_id" {
  description = "Etiqueta 802.1Q. null = untagged (modo flat da fase 1)."
  type        = number
  default     = null
}

variable "mac_address" {
  description = <<-EOT
    MAC fixo. Necessario quando o endereco vem de reserva DHCP ou quando o
    instalador do OpenShift o exige no agent-config.yaml.
  EOT
  type        = string
  default     = null
}

variable "ipv4_address" {
  description = "Endereco CIDR para cloud-init, ou 'dhcp'."
  type        = string
  default     = "dhcp"
}

variable "ipv4_gateway" {
  description = "Gateway para cloud-init. Ignorado quando ipv4_address = dhcp."
  type        = string
  default     = null
}

# ---------- Arranque ----------
variable "started" {
  description = "Estado desejado. Os perfis de memoria mudam isto em runtime, nao aqui."
  type        = bool
  default     = false
}

variable "on_boot" {
  description = "Arranca com o host. So true para os guests sempre-ligados."
  type        = bool
  default     = false
}

variable "startup" {
  description = <<-EOT
    Ordem de arranque com o host. Menor arranca primeiro — o opnsense antes de
    tudo, porque sem ele nao ha DNS de lab. null desliga a gestao de ordem.
  EOT
  type = object({
    order      = optional(number)
    up_delay   = optional(number)
    down_delay = optional(number)
  })
  default = null
}

# ---------- Imagem ----------
variable "clone_vm_id" {
  description = "VMID do template a clonar. null quando se arranca de ISO."
  type        = number
  default     = null
}

variable "iso_file_id" {
  description = "ISO de arranque (ex.: 'local:iso/agent.x86_64.iso'). null quando se clona."
  type        = string
  default     = null
}

variable "bios" {
  description = "'seabios' ou 'ovmf'. OVMF e obrigatorio para passthrough de GPU."
  type        = string
  default     = "seabios"
}

variable "machine" {
  description = "'q35' expoe topologia PCIe real — requisito para passthrough."
  type        = string
  default     = "q35"
}

variable "os_type" {
  description = "Tipo de sistema operativo para o Proxmox."
  type        = string
  default     = "l26"
}

# ---------- Passthrough ----------
variable "hostpci_devices" {
  description = <<-EOT
    Dispositivos PCI a passar. O 'id' e o endereco PCI apurado no metal
    (ver docs/gpu-passthrough.md) — nunca escrito a mao no repositorio.
  EOT
  type = list(object({
    device = string
    id     = string
    pcie   = optional(bool, true)
    rombar = optional(bool, true)
    xvga   = optional(bool, false)
  }))
  default = []
}

variable "usb_devices" {
  description = "Dispositivos ou controladores USB a passar."
  type = list(object({
    host = string
    usb3 = optional(bool, true)
  }))
  default = []
}

# ---------- cloud-init ----------
variable "cloud_init_enabled" {
  description = "Falso para appliances fechadas (Home Assistant OS) e para RHCOS."
  type        = bool
  default     = true
}

variable "ssh_public_keys" {
  description = "Chaves publicas injectadas por cloud-init."
  type        = list(string)
  default     = []
}

variable "username" {
  description = "Utilizador criado por cloud-init."
  type        = string
  default     = "sergio"
}
