# Um guest KVM no Proxmox.
#
# Deliberadamente opinativo: agent ligado, discos SSD com discard e iothread,
# arranque parado por omissao (os perfis de memoria e que decidem o que sobe).

locals {
  needs_efi = var.bios == "ovmf"
  is_cloned = var.clone_vm_id != null
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description
  tags        = concat(["opentofu"], var.tags)

  machine       = var.machine
  bios          = var.bios
  scsi_hardware = "virtio-scsi-single"

  started         = var.started
  on_boot         = var.on_boot
  stop_on_destroy = true

  agent {
    enabled = var.cloud_init_enabled
    trim    = true
  }

  operating_system {
    type = var.os_type
  }

  cpu {
    cores    = var.cores
    sockets  = 1
    type     = var.cpu_type
    affinity = var.cpu_affinity == "" ? null : var.cpu_affinity
  }

  memory {
    dedicated      = var.memory_mb
    floating       = var.memory_floating_mb
    hugepages      = var.hugepages
    keep_hugepages = var.hugepages != null
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
    cache        = "none"
  }

  dynamic "efi_disk" {
    for_each = local.needs_efi ? [1] : []
    content {
      datastore_id      = var.datastore_id
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = false
    }
  }

  # network_device e um atributo (lista de objectos), nao um bloco.
  # O tipo do provider exige que todos os campos do objecto sejam declarados,
  # mesmo os que ficam a null.
  network_device = [{
    bridge       = "vmbr0"
    model        = "virtio"
    vlan_id      = var.vlan_id
    mac_address  = var.mac_address
    queues       = var.cores > 4 ? 4 : 1
    firewall     = false
    enabled      = true
    disconnected = false
    mtu          = null
    rate_limit   = null
    trunks       = null
  }]

  dynamic "startup" {
    for_each = var.startup == null ? [] : [var.startup]
    content {
      order      = startup.value.order
      up_delay   = startup.value.up_delay
      down_delay = startup.value.down_delay
    }
  }

  dynamic "clone" {
    for_each = local.is_cloned ? [1] : []
    content {
      vm_id = var.clone_vm_id
      full  = true
    }
  }

  dynamic "cdrom" {
    for_each = var.iso_file_id == null ? [] : [1]
    content {
      file_id = var.iso_file_id
    }
  }

  dynamic "initialization" {
    for_each = var.cloud_init_enabled ? [1] : []
    content {
      datastore_id = var.datastore_id
      interface    = "ide2"

      ip_config {
        ipv4 {
          address = var.ipv4_address
          gateway = var.ipv4_address == "dhcp" ? null : var.ipv4_gateway
        }
      }

      user_account {
        username = var.username
        keys     = var.ssh_public_keys
      }
    }
  }

  dynamic "hostpci" {
    for_each = { for d in var.hostpci_devices : d.device => d }
    content {
      device = hostpci.value.device
      id     = hostpci.value.id
      pcie   = hostpci.value.pcie
      rombar = hostpci.value.rombar
      xvga   = hostpci.value.xvga
    }
  }

  dynamic "usb" {
    for_each = { for i, d in var.usb_devices : i => d }
    content {
      host = usb.value.host
      usb3 = usb.value.usb3
    }
  }

  lifecycle {
    # O estado ligado/parado pertence aos perfis de memoria (scripts/profile.sh),
    # nao ao OpenTofu. Sem isto, cada apply lutaria contra o ultimo make profile-*.
    ignore_changes = [started]
  }
}
