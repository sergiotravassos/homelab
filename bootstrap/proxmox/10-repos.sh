#!/usr/bin/env bash
# Repositorios: trocar o enterprise (que exige subscricao) pelo no-subscription.
# Idempotente.
set -euo pipefail
echo "[10-repos] a configurar repositorios"

# Proxmox VE 9 usa o formato deb822 em /etc/apt/sources.list.d/*.sources
for f in /etc/apt/sources.list.d/pve-enterprise.sources \
         /etc/apt/sources.list.d/ceph.sources; do
  if [[ -f "$f" ]] && ! grep -q '^Enabled: false' "$f"; then
    printf '\nEnabled: false\n' >>"$f"
    echo "  desactivado $f"
  fi
done

# formato antigo, caso venha de uma versao anterior
for f in /etc/apt/sources.list.d/pve-enterprise.list \
         /etc/apt/sources.list.d/ceph.list; do
  [[ -f "$f" ]] && sed -i 's/^deb /# deb /' "$f" && echo "  comentado $f"
done

cat >/etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get -y -qq dist-upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y -qq install \
  vim git curl jq htop iotop lm-sensors ethtool tmux \
  fail2ban unattended-upgrades hwloc python3-proxmoxer

echo "[10-repos] ok"
