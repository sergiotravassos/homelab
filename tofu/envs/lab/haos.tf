# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara a VM do Home Assistant OS.
#  PORQUE EXISTE  É o guest de que a casa depende — daí ser dos dois que arrancam com o host.
#  SE TIRARES     A automação da casa deixa de existir. É o guest com consequência real.
#  ONDE APRENDER  docs/percurso.md — etapa 2. Lê este primeiro: é o guest mais simples do repo.
# ──────────────────────────────────────────────────────────────────────────────
#
#  Porque é que o cloud-init está desligado: o Home Assistant OS é uma appliance
#  fechada, distribuída como imagem pronta. Não há utilizador para criar nem
#  chave SSH para injectar — configura-se pela interface dele.
#
#  Nota importante no fim do ficheiro sobre um passo manual de importação.

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
