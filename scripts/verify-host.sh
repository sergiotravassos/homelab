#!/usr/bin/env bash
# Verifica o estado do host depois do bootstrap. Corre no proprio Proxmox.
# Nao altera nada.
set -uo pipefail

ok=0; bad=0
chk() { # $1=descricao $2=comando
  if eval "$2" >/dev/null 2>&1; then
    printf '  \033[32m OK \033[0m %s\n' "$1"; ok=$((ok+1))
  else
    printf '  \033[31mFALHA\033[0m %s\n' "$1"; bad=$((bad+1))
  fi
}

echo "== verificacao do host $(hostname) =="

echo "-- virtualizacao"
chk "IOMMU activo"            "dmesg | grep -qiE 'AMD-Vi|IOMMU enabled'"
chk "iommu=pt aplicado"       "grep -qs 'iommu=pt' /proc/cmdline"
chk "modulos vfio carregados" "lsmod | grep -q '^vfio_pci'"
if lspci -nnk -d 1002: 2>/dev/null | grep -q 'Kernel driver in use: vfio-pci'; then
  printf '  \033[32m OK \033[0m GPU ligada ao vfio-pci\n'; ok=$((ok+1))
else
  printf '  \033[33mAVISO\033[0m GPU ainda nao esta no vfio-pci (normal antes de make configure-host)\n'
fi

echo "-- armazenamento"
chk "rpool saudavel"          "zpool status rpool | grep -q 'state: ONLINE'"
chk "rpool sem erros"         "! zpool status rpool | grep -qE 'errors: [^N]'"
chk "atime desligado"         "[ \"\$(zfs get -H -o value atime rpool)\" = off ]"
chk "compressao zstd"         "zfs get -H -o value compression rpool | grep -q zstd"
chk "ARC limitada"            "[ \"\$(cat /sys/module/zfs/parameters/zfs_arc_max)\" -gt 0 ]"
USED=$(zpool list -H -o capacity rpool | tr -d '%')
if [[ "$USED" -lt 80 ]]; then
  printf '  \033[32m OK \033[0m rpool a %s%% de ocupacao\n' "$USED"; ok=$((ok+1))
else
  printf '  \033[31mFALHA\033[0m rpool a %s%% — acima de 80%% o ZFS degrada em escrita\n' "$USED"; bad=$((bad+1))
fi

echo "-- rede"
chk "vmbr0 existe"            "ip link show vmbr0"
chk "vmbr0 VLAN-aware"        "grep -q 'bridge-vlan-aware yes' /etc/network/interfaces"
chk "gateway alcancavel"      "ping -c1 -W2 \$(ip route | awk '/default/{print \$3; exit}')"

echo "-- seguranca"
chk "SSH so por chave"        "grep -qs 'PasswordAuthentication no' /etc/ssh/sshd_config.d/99-homelab.conf"
chk "fail2ban activo"         "systemctl is-active --quiet fail2ban"
chk "token do OpenTofu"       "pveum user token list tofu@pve --output-format json | grep -q homelab"

echo "-- memoria"
free -g | awk '/^Mem:/ {printf "  total %sG · usada %sG · disponivel %sG\n", $2, $3, $7}'
ARC=$(awk '/^size/ {printf "%.1f", $3/1024/1024/1024}' /proc/spl/kstat/zfs/arcstats 2>/dev/null || echo "?")
echo "  ARC actual: ${ARC}G"

echo
echo "== $ok verificacoes passaram, $bad falharam =="
[[ "$bad" -eq 0 ]]
