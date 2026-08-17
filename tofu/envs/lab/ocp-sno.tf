# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara a VM do cluster OpenShift de nó único.
#  PORQUE EXISTE  É o terreno profissional deste lab: Quarkus, Kafka, Argo CD. Também o
#                 maior consumidor de RAM — 24 GB dos 58 disponíveis.
#  SE TIRARES     Fica um lab de virtualização sem plataforma. Metade do objectivo.
#  ONDE APRENDER  docs/percurso.md — etapa 6
# ──────────────────────────────────────────────────────────────────────────────
#
#  Três detalhes que não são arbitrários:
#
#    memory_floating_mb = 0   o OpenShift lida mal com RAM a desaparecer
#    cloud_init_enabled = false o RHCOS usa Ignition, não cloud-init
#    mac_address              TEM de coincidir com openshift/install/agent-config.yaml,
#                             senão o nó arranca e nunca recebe rede

module "ocp_sno" {
  source = "../../modules/proxmox-vm"

  name        = "ocp-sno"
  vm_id       = 120
  node_name   = var.node_name
  description = "OpenShift SNO · 24 GB sem balloon · perfil platform"
  tags        = concat(local.common_tags, ["openshift", "plataforma"])

  cores        = 12
  cpu_affinity = var.cpu_ccd1_cpus
  memory_mb    = 24576

  # sem ballooning: o OpenShift lida mal com memoria a desaparecer debaixo dos pes
  memory_floating_mb = 0

  disk_size_gb = 200
  datastore_id = var.datastore_id

  vlan_id      = local.vlan.platform
  mac_address  = local.mac.ocp_sno
  ipv4_address = local.net.ocp_sno.addr
  ipv4_gateway = local.net.ocp_sno.gw

  on_boot = false
  started = false

  # RHCOS configura-se por Ignition, nao por cloud-init
  cloud_init_enabled = false
  bios               = "ovmf"
  iso_file_id        = var.ocp_iso_file_id
}
