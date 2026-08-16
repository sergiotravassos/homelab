#!/usr/bin/env bash
# Endurecimento basico. Nao substitui a firewall do OPNsense — complementa.
set -euo pipefail
echo "[60-hardening] a endurecer o host"

# --- SSH: so por chave ---
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-homelab.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
EOF

if [[ ! -s /root/.ssh/authorized_keys ]]; then
  echo "  AVISO: /root/.ssh/authorized_keys esta vazio."
  echo "  A NAO desligar a autenticacao por palavra-passe — ficarias sem acesso."
  rm -f /etc/ssh/sshd_config.d/99-homelab.conf
else
  sshd -t && systemctl reload ssh
  echo "  SSH: apenas por chave"
fi

# --- fail2ban para a interface web e o SSH ---
cat >/etc/fail2ban/jail.d/proxmox.local <<'EOF'
[proxmox]
enabled  = true
port     = https,http,8006
filter   = proxmox
logpath  = /var/log/daemon.log
maxretry = 3
bantime  = 3600
findtime = 600

[sshd]
enabled  = true
maxretry = 3
bantime  = 3600
EOF

cat >/etc/fail2ban/filter.d/proxmox.conf <<'EOF'
[Definition]
failregex = pvedaemon\[.*authentication (verification )?failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban

# --- actualizacoes de seguranca automaticas (so security, sem reinicio) ---
cat >/etc/apt/apt.conf.d/51homelab-unattended <<'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
EOF
systemctl enable --now unattended-upgrades

# --- remover o aviso de subscricao da interface web ---
SCRIPT=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
if [[ -f "$SCRIPT" ]] && ! grep -q 'homelab-nosub' "$SCRIPT"; then
  cp "$SCRIPT" "${SCRIPT}.bak"
  sed -i "s/data.status.toLowerCase() !== 'active'/false \/*homelab-nosub*\//g" "$SCRIPT"
  systemctl restart pveproxy
fi

# --- sensores ---
sensors-detect --auto >/dev/null 2>&1 || true

echo "[60-hardening] ok"
