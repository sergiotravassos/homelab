# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara o contentor de monitorização: Prometheus e Grafana.
#  PORQUE EXISTE  O OpenShift é sob procura; a máquina tem de ser observada sempre,
#                 incluindo durante os jogos e com o cluster desligado.
#  SE TIRARES     Ficas sem temperaturas, consumo por VM e métricas da GPU fora do cluster.
#  ONDE APRENDER  docs/adr/0010-monitorizacao-fora-do-openshift.md
# ──────────────────────────────────────────────────────────────────────────────
#
#  Está na VLAN 20 e não na 10 de propósito: o painel de parede (VLAN 30) lê o
#  Grafana, e a MGMT nunca é alcançável a partir da IOT. O preço são duas
#  regras de saída estreitas, a partir deste contentor — ver docs/network.md.
#
#  on_boot = true: pertence ao perfil idle, arranca com o host.

module "monitoring" {
  source = "../../modules/proxmox-lxc"

  name        = "monitoring"
  vm_id       = 203
  node_name   = var.node_name
  description = "Prometheus e Grafana · sempre ligado · ADR 0010"
  tags        = concat(local.common_tags, ["observabilidade"])

  cores        = 2
  memory_mb    = 1024
  disk_size_gb = 30
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.platform
  ipv4_address     = local.net.monitoring.addr
  ipv4_gateway     = local.net.monitoring.gw
  ssh_public_keys  = var.ssh_public_keys

  on_boot = true
}
