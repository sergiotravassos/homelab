# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara o contentor do Proxmox Backup Server.
#  PORQUE EXISTE  Os vzdump nocturnos precisam de um destino que não seja a rpool:
#                 um backup no mesmo disco que os dados não protege de nada.
#  SE TIRARES     Não há backups. O haos e o opnsense deixam de ser recuperáveis.
#  ONDE APRENDER  docs/runbooks/03-backup-e-restauro.md
# ──────────────────────────────────────────────────────────────────────────────
#
#  O datastore vive num disco externo, registado no Proxmox como storage
#  próprio (var.pbs_datastore_storage). O contentor recebe um volume nesse
#  storage, montado em /datastore. Com a variável a null não há volume — serve
#  para criar o contentor antes de o disco existir.
#
#  Porque um volume e não um bind mount do host: bind mounts só os pode criar o
#  root@pam, e o OpenTofu entra com um token de API de privilégio mínimo.

module "pbs" {
  source = "../../modules/proxmox-lxc"

  name        = "pbs"
  vm_id       = 105
  node_name   = var.node_name
  description = "Proxmox Backup Server · sempre ligado · datastore fora da rpool"
  tags        = concat(local.common_tags, ["backup"])

  cores        = 2
  memory_mb    = 2048
  disk_size_gb = 16
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.mgmt
  ipv4_address     = local.net.pbs.addr
  ipv4_gateway     = local.net.pbs.gw
  ssh_public_keys  = var.ssh_public_keys

  mount_points = var.pbs_datastore_storage == null ? [] : [
    {
      volume = var.pbs_datastore_storage
      path   = "/datastore"
      size   = var.pbs_datastore_size
    }
  ]

  on_boot = true
}
