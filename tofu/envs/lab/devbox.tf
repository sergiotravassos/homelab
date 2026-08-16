# Bancada de desenvolvimento. Fedora Silverblue a partir do template Packer,
# depois rebase para a imagem bootc propria (ver bootc/devbox/).
#
# E aqui que o codigo compila — nao no MacBook. Ver docs/workflow.md

module "devbox" {
  source = "../../modules/proxmox-vm"

  name        = "devbox"
  vm_id       = 130
  node_name   = var.node_name
  description = "Bancada de desenvolvimento · alvo do JetBrains Gateway"
  tags        = concat(local.common_tags, ["dev"])

  cores        = 8
  cpu_affinity = var.cpu_ccd1_cpus
  memory_mb    = 16384

  # balloon 8-16: uma IDE remota parada nao precisa de 16 GB, mas um
  # native-image precisa. Ver docs/capacity.md
  memory_floating_mb = 8192

  disk_size_gb = 150
  datastore_id = var.datastore_id

  vlan_id      = local.vlan.dev
  mac_address  = local.mac.devbox
  ipv4_address = local.net.devbox.addr
  ipv4_gateway = local.net.devbox.gw

  on_boot = false
  started = false

  clone_vm_id     = var.fedora_template_vm_id
  ssh_public_keys = var.ssh_public_keys
  username        = var.username
}
