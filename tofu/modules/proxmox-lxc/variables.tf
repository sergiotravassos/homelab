variable "name" {
  description = "Nome do contentor, usado tambem como hostname."
  type        = string
}

variable "vm_id" {
  description = "VMID fixo."
  type        = number
}

variable "node_name" {
  description = "Nome do no Proxmox."
  type        = string
}

variable "description" {
  type    = string
  default = "Gerido por OpenTofu — nao editar na interface web"
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cores" {
  description = "vCPU. Os LXC partilham; sobrecomprometer aqui e normal."
  type        = number
  default     = 2
}

variable "memory_mb" {
  type = number
}

variable "swap_mb" {
  description = "Swap. Zero por omissao: swap num servico de dados esconde problemas."
  type        = number
  default     = 0
}

variable "disk_size_gb" {
  type = number
}

variable "datastore_id" {
  type    = string
  default = "local-zfs"
}

variable "template_file_id" {
  description = "Template de contentor (ex.: 'local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst')."
  type        = string
}

variable "os_type" {
  type    = string
  default = "debian"
}

variable "vlan_id" {
  description = "Etiqueta 802.1Q. null = untagged."
  type        = number
  default     = null
}

variable "ipv4_address" {
  description = "Endereco CIDR ou 'dhcp'."
  type        = string
}

variable "ipv4_gateway" {
  type    = string
  default = null
}

variable "started" {
  type    = bool
  default = false
}

variable "on_boot" {
  type    = bool
  default = false
}

variable "unprivileged" {
  description = "Contentores nao-privilegiados por omissao. Mudar exige justificacao."
  type        = bool
  default     = true
}

variable "features" {
  description = "Funcionalidades do contentor. 'nesting' e necessario para correr Podman dentro."
  type = object({
    nesting = optional(bool, true)
    fuse    = optional(bool, false)
    keyctl  = optional(bool, false)
  })
  default = {}
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}

variable "mount_points" {
  description = "Pontos de montagem adicionais, para dados que sobrevivem ao contentor."
  type = list(object({
    volume = string
    path   = string
    size   = optional(string)
  }))
  default = []
}
