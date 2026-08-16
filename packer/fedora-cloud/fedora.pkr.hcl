# Template Fedora cloud para o Proxmox.
#
# Constroi UMA vez a imagem base de que o devbox e clonado. Sem isto, cada
# guest descarregaria e instalaria o sistema do zero — lento e nao reprodutivel.
#
#   make template

packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2"
    }
  }
}

variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_VE_ENDPOINT")
}

variable "proxmox_node" {
  type    = string
  default = "forge"
}

variable "proxmox_token" {
  type      = string
  default   = env("PROXMOX_VE_API_TOKEN")
  sensitive = true
}

variable "fedora_version" {
  type    = string
  default = "42"
}

variable "template_vm_id" {
  type    = number
  default = 9000
}

locals {
  image_url = join("", [
    "https://download.fedoraproject.org/pub/fedora/linux/releases/",
    var.fedora_version,
    "/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-",
    var.fedora_version,
    "-1.1.x86_64.qcow2"
  ])
}

source "proxmox-clone" "fedora" {
  proxmox_url              = var.proxmox_url
  username                 = split("=", var.proxmox_token)[0]
  token                    = split("=", var.proxmox_token)[1]
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                = var.template_vm_id
  vm_name              = "fedora-${var.fedora_version}-cloud"
  template_description = "Fedora ${var.fedora_version} cloud · construido por Packer · nao editar a mao"

  clone_vm_id = 9999 # VM semente criada a partir do qcow2 oficial

  cores   = 2
  memory  = 2048
  os      = "l26"
  machine = "q35"
  bios    = "ovmf"

  scsi_controller = "virtio-scsi-single"

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  cloud_init              = true
  cloud_init_storage_pool = "local-zfs"

  ssh_username         = "sergio"
  ssh_private_key_file = "~/.ssh/id_ed25519"
  ssh_timeout          = "15m"
}

build {
  sources = ["source.proxmox-clone.fedora"]

  provisioner "shell" {
    inline = [
      "sudo dnf -y upgrade --refresh",
      "sudo dnf -y install qemu-guest-agent cloud-init python3-libdnf5",
      "sudo systemctl enable qemu-guest-agent",
      # limpar o estado do cloud-init para o template arrancar limpo em cada clone
      "sudo cloud-init clean --logs --seed",
      "sudo rm -f /etc/machine-id && sudo touch /etc/machine-id",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo dnf clean all",
    ]
  }
}
