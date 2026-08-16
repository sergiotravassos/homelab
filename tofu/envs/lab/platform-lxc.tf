# Servicos de plataforma com estado, fora do cluster.
#
# Em LXC e nao em VM por uma razao concreta: tres VMs custariam ~6 GB so em
# kernels e sistemas de ficheiros. Ver docs/capacity.md
#
# Servem o devbox quando o OpenShift esta desligado — que e a maior parte do tempo.

module "kafka" {
  source = "../../modules/proxmox-lxc"

  name        = "kafka"
  vm_id       = 200
  node_name   = var.node_name
  description = "Kafka em modo KRaft · testes locais sem o cluster"
  tags        = concat(local.common_tags, ["plataforma", "dados"])

  cores        = 2
  memory_mb    = 4096
  disk_size_gb = 40
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.platform
  ipv4_address     = local.net.kafka.addr
  ipv4_gateway     = local.net.kafka.gw
  ssh_public_keys  = var.ssh_public_keys
}

module "postgres" {
  source = "../../modules/proxmox-lxc"

  name        = "postgres"
  vm_id       = 201
  node_name   = var.node_name
  description = "PostgreSQL 16 · base de dados de desenvolvimento"
  tags        = concat(local.common_tags, ["plataforma", "dados"])

  cores        = 2
  memory_mb    = 4096
  disk_size_gb = 40
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.platform
  ipv4_address     = local.net.postgres.addr
  ipv4_gateway     = local.net.postgres.gw
  ssh_public_keys  = var.ssh_public_keys
}

module "registry" {
  source = "../../modules/proxmox-lxc"

  name        = "registry"
  vm_id       = 202
  node_name   = var.node_name
  description = "Registry OCI local · imagens do dia-a-dia"
  tags        = concat(local.common_tags, ["plataforma"])

  cores        = 2
  memory_mb    = 2048
  disk_size_gb = 60
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.platform
  ipv4_address     = local.net.registry.addr
  ipv4_gateway     = local.net.registry.gw
  ssh_public_keys  = var.ssh_public_keys

  # o registry corre em Podman dentro do contentor
  features = {
    nesting = true
    keyctl  = true
  }
}
