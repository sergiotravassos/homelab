# Router e firewall do laboratorio. Nao substitui o router de casa —
# ver docs/adr/0005-vlans-com-switch-gerivel.md
#
# Arranca primeiro: sem ele nao ha DNS de lab nem encaminhamento inter-VLAN.

module "opnsense" {
  source = "../../modules/proxmox-vm"

  name        = "opnsense-lab"
  vm_id       = 100
  node_name   = var.node_name
  description = "Router e firewall do lab · sempre ligado · gerido por OpenTofu"
  tags        = concat(local.common_tags, ["rede", "sempre-ligado"])

  cores        = 2
  cpu_affinity = var.cpu_ccd1_cpus
  memory_mb    = 2048
  disk_size_gb = 20
  datastore_id = var.datastore_id

  # trunk: recebe todas as VLANs, sem etiqueta propria
  vlan_id      = null
  mac_address  = local.mac.opnsense
  ipv4_address = local.net.opnsense.addr
  ipv4_gateway = local.net.opnsense.gw

  on_boot = true
  started = false
  startup = { order = 1 }

  # FreeBSD: sem cloud-init e sem qemu-guest-agent no arranque inicial
  cloud_init_enabled = false
  os_type            = "other"
  bios               = "ovmf"
}
