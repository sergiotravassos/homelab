# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Diz ao OpenTofu como falar com o Proxmox.
#  PORQUE EXISTE  Um provider é o adaptador que traduz este HCL em chamadas HTTP à API do
#                 Proxmox. Sem ele o OpenTofu não sabe o que é uma VM.
#  SE TIRARES     Nada consegue ser criado — não há ligação a lado nenhum.
#  ONDE APRENDER  docs/percurso.md — etapa 2
# ──────────────────────────────────────────────────────────────────────────────
#
#  Repara no que NÃO está aqui: o token. Vem do ambiente (.envrc → Keychain do
#  macOS). Um segredo neste ficheiro seria um segredo num repositório público.

provider "proxmox" {
  # certificado auto-assinado do lab; nao ha CA interna a emiti-lo
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}
