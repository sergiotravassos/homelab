# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Fixa a versão do OpenTofu e do provider do Proxmox.
#  PORQUE EXISTE  O provider bpg/proxmox muda campos entre versões menores. Sem fixar, um
#                 `tofu init` amanhã podia falhar sem tu mudares uma linha.
#  SE TIRARES     O init apanha a versão mais recente, que pode já não aceitar este código.
#  ONDE APRENDER  docs/percurso.md — etapa 2. Começa por aqui: é o ficheiro mais pequeno do repo.
# ──────────────────────────────────────────────────────────────────────────────
#
#  `~> 0.78` significa: aceita 0.78.x, recusa 0.79. Deixa entrar correcções,
#  não deixa entrar mudanças de comportamento.

terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}
