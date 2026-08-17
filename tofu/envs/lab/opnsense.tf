# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara a VM do router e firewall do laboratório.
#  PORQUE EXISTE  É quem encaminha entre VLANs e resolve DNS do lab. Sem ele, em modo vlan,
#                 nada se alcança e o OpenShift não instala.
#  SE TIRARES     Não há DNS de lab nem rotas entre VLANs. O modo flat continua a funcionar.
#  ONDE APRENDER  docs/percurso.md — etapa 4
# ──────────────────────────────────────────────────────────────────────────────
#
#  `vlan_id = null` aqui não significa "modo flat" — significa que esta VM está
#  no trunk e recebe TODAS as VLANs sem etiqueta própria. É ela que as separa
#  em sub-interfaces lá dentro. É a diferença entre uma porta trunk e uma access.
#
#  `startup = { order = 1 }`: arranca antes de todos os outros guests.

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
