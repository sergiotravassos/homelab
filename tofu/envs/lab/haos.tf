# Home Assistant OS. Appliance fechada: imagem qcow2 oficial, sem cloud-init.
# E o unico guest de que a casa depende — daqui o "sempre ligado".

module "haos" {
  source = "../../modules/proxmox-vm"

  name        = "haos"
  vm_id       = 110
  node_name   = var.node_name
  description = "Home Assistant OS · sempre ligado · a casa depende deste guest"
  tags        = concat(local.common_tags, ["iot", "sempre-ligado"])

  cores        = 2
  cpu_affinity = var.cpu_ccd1_cpus
  memory_mb    = 4096
  disk_size_gb = 32
  datastore_id = var.datastore_id

  vlan_id      = local.vlan.iot
  mac_address  = local.mac.haos
  ipv4_address = local.net.haos.addr
  ipv4_gateway = local.net.haos.gw

  on_boot = true
  started = false
  startup = { order = 2, up_delay = 30 }

  cloud_init_enabled = false
  bios               = "ovmf"

  # dongle Zigbee/Z-Wave
  usb_devices = var.zigbee_usb_host == null ? [] : [
    { host = var.zigbee_usb_host, usb3 = false }
  ]
}

# NOTA: o disco desta VM tem de ser importado a partir da imagem qcow2 oficial.
# O provider nao descarrega imagens de disco de guest; e um passo do runbook:
#
#   qm importdisk 110 haos_ova-*.qcow2 local-zfs
#
# Ver docs/runbooks/ — fica registado aqui para nao surpreender no primeiro apply.
