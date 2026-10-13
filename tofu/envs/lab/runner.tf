# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Declara o contentor do runner self-hosted de deploy.
#  PORQUE EXISTE  Deploys do projecto pessoal sem minutos pagos e com acesso ao que só
#                 existe em casa.
#  SE TIRARES     Os deploys voltam para os runners alojados do GitHub.
#  ONDE APRENDER  docs/adr/0012-runner-de-deploy-do-hobby.md
# ──────────────────────────────────────────────────────────────────────────────
#
#  Três regras deste guest, todas do ADR:
#    · efémero — o runner regista-se com --ephemeral, um job e sai
#    · só repositórios privados — num público, um PR de fork corria código aqui
#    · sob procura — fora dos perfis; liga-se com `make runner-start`
#
#  nesting e keyctl: o deploy pode construir imagens com Podman, como o registry.

module "runner" {
  source = "../../modules/proxmox-lxc"

  name        = "runner"
  vm_id       = 204
  node_name   = var.node_name
  description = "Runner de deploy efémero · sob procura · ADR 0012"
  tags        = concat(local.common_tags, ["ci"])

  cores        = 2
  memory_mb    = 2048
  disk_size_gb = 30
  datastore_id = var.datastore_id

  template_file_id = var.debian_template
  vlan_id          = local.vlan.platform
  ipv4_address     = local.net.runner.addr
  ipv4_gateway     = local.net.runner.gw
  ssh_public_keys  = var.ssh_public_keys

  features = {
    nesting = true
    keyctl  = true
  }
}
