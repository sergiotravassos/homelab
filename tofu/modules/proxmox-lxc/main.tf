# Um contentor LXC no Proxmox.
#
# Usado para os servicos de plataforma com estado — Kafka, PostgreSQL, registry.
# Uma VM inteira para cada um custaria memoria que este lab nao tem
# (ver docs/capacity.md).

resource "proxmox_virtual_environment_container" "this" {
  vm_id        = var.vm_id
  node_name    = var.node_name
  description  = var.description
  tags         = concat(["opentofu"], var.tags)
  unprivileged = var.unprivileged

  started       = var.started
  start_on_boot = var.on_boot

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size_gb
  }

  dynamic "mount_point" {
    for_each = { for m in var.mount_points : m.path => m }
    content {
      volume = mount_point.value.volume
      path   = mount_point.value.path
      size   = mount_point.value.size
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.vlan_id
    enabled = true
  }

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_address == "dhcp" ? null : var.ipv4_gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  features {
    nesting = var.features.nesting
    fuse    = var.features.fuse
    keyctl  = var.features.keyctl
  }

  lifecycle {
    # Ver a nota equivalente em proxmox-vm: o estado ligado pertence aos perfis.
    ignore_changes = [started]
  }
}
