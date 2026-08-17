# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Guarda o plano de endereçamento e o interruptor flat/vlan num sítio só.
#  PORQUE EXISTE  Se cada guest declarasse o seu IP, mudar de fase de rede seria editar oito
#                 ficheiros. Aqui é mudar uma variável.
#  SE TIRARES     Cada ficheiro de guest passaria a repetir IPs e etiquetas à mão.
#  ONDE APRENDER  docs/percurso.md — etapa 2, e a etapa 4 para a parte das VLANs
# ──────────────────────────────────────────────────────────────────────────────
#
#  `locals` são valores calculados, não entradas. A diferença face a `variable`:
#  uma variável vem de fora, um local é derivado aqui dentro.
#
#  O padrão `condição ? A : B` aparece três vezes. Lê-se: em modo vlan usa o
#  mapa A (etiquetas e IPs fixos), senão usa B (tudo null e dhcp).

locals {
  vlan = var.network_mode == "vlan" ? {
    mgmt     = 10
    platform = 20
    iot      = 30
    gaming   = 40
    dev      = 50
    } : {
    # fase 1: tudo untagged na LAN de casa
    mgmt     = null
    platform = null
    iot      = null
    gaming   = null
    dev      = null
  }

  # Em modo flat os enderecos vem do DHCP do router de casa; em modo vlan
  # sao estaticos e seguem a convencao "ultimo octeto repete a VLAN".
  net = var.network_mode == "vlan" ? {
    opnsense = { addr = "10.10.10.1/24", gw = "10.10.10.1" }
    haos     = { addr = "10.10.30.30/24", gw = "10.10.30.1" }
    ocp_sno  = { addr = "10.10.20.20/24", gw = "10.10.20.1" }
    devbox   = { addr = "10.10.50.50/24", gw = "10.10.50.1" }
    bazzite  = { addr = "10.10.40.40/24", gw = "10.10.40.1" }
    kafka    = { addr = "10.10.20.21/24", gw = "10.10.20.1" }
    postgres = { addr = "10.10.20.22/24", gw = "10.10.20.1" }
    registry = { addr = "10.10.20.23/24", gw = "10.10.20.1" }
    } : {
    opnsense = { addr = "dhcp", gw = null }
    haos     = { addr = "dhcp", gw = null }
    ocp_sno  = { addr = "dhcp", gw = null }
    devbox   = { addr = "dhcp", gw = null }
    bazzite  = { addr = "dhcp", gw = null }
    kafka    = { addr = "dhcp", gw = null }
    postgres = { addr = "dhcp", gw = null }
    registry = { addr = "dhcp", gw = null }
  }

  # MAC fixos: o instalador do OpenShift exige-o no agent-config.yaml e as
  # reservas de DHCP dependem deles. Prefixo BC:24:11 = OUI do Proxmox.
  mac = {
    opnsense = "BC:24:11:00:01:00"
    haos     = "BC:24:11:00:01:10"
    ocp_sno  = "BC:24:11:00:01:20"
    devbox   = "BC:24:11:00:01:30"
    bazzite  = "BC:24:11:00:01:40"
  }

  common_tags = ["homelab"]
}
