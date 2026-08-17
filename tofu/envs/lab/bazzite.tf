# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara a VM da Steam Machine, com a GPU em passthrough.
#  PORQUE EXISTE  É o guest que justifica metade das escolhas de hardware: a GPU dedicada,
#                 o pinning no CCD com V-Cache, as hugepages.
#  SE TIRARES     Ficas sem consola na sala. A GPU fica sem uso — não há outra carga a
#                 usá-la.
#  ONDE APRENDER  docs/percurso.md — etapa 5. É o ficheiro mais complexo do repo; deixa-o para depois do haos.tf.
# ──────────────────────────────────────────────────────────────────────────────
#
#  Único guest fixado no CCD 0 — os oito cores com 64 MB de cache empilhada.
#
#  `gpu_pci_id == null ? [] : [...]` significa: sem endereço PCI apurado, não
#  passa GPU nenhuma. É deliberado — deixa arrancar a VM sem GPU para
#  diagnosticar, em vez de falhar com um valor inventado.

module "bazzite" {
  source = "../../modules/proxmox-vm"

  name        = "bazzite"
  vm_id       = 140
  node_name   = var.node_name
  description = "Steam Machine · GPU em passthrough · exclusiva com cargas GPU"
  tags        = concat(local.common_tags, ["gaming", "gpu"])

  cores        = 8
  cpu_affinity = var.cpu_ccd0_cpus
  cpu_type     = "host"

  memory_mb          = 16384
  memory_floating_mb = 0
  hugepages          = "1024"

  disk_size_gb = 250
  datastore_id = var.datastore_id

  vlan_id      = local.vlan.gaming
  mac_address  = local.mac.bazzite
  ipv4_address = local.net.bazzite.addr
  ipv4_gateway = local.net.bazzite.gw

  on_boot = false
  started = false

  # q35 + OVMF sao requisito para passthrough de GPU moderna
  machine            = "q35"
  bios               = "ovmf"
  cloud_init_enabled = false

  hostpci_devices = var.gpu_pci_id == null ? [] : [
    {
      device = "hostpci0"
      id     = var.gpu_pci_id
      pcie   = true
      rombar = true
      xvga   = true
    }
  ]

  # controlador inteiro, nao portas individuais: assim os comandos ligam e
  # desligam a quente sem alterar a configuracao da VM
  usb_devices = var.usb_controller_host == null ? [] : [
    { host = var.usb_controller_host, usb3 = true }
  ]
}
