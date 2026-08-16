# Autenticacao vem do ambiente, carregada pelo direnv a partir do .envrc:
#   PROXMOX_VE_ENDPOINT
#   PROXMOX_VE_API_TOKEN   (lido do Keychain do macOS, nunca de um ficheiro)
#   PROXMOX_VE_INSECURE
#
# Ver .envrc.example e docs/adr/0007-segredos-sops-age.md

provider "proxmox" {
  # certificado auto-assinado do lab; nao ha CA interna a emiti-lo
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}
