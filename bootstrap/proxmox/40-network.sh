#!/usr/bin/env bash
# Bridge VLAN-aware. NAO muda o endereco de gestao: essa migracao faz-se na consola
# local, no passo 5 do runbook 01. Mudar o IP pela rede corta o acesso a meio.
set -euo pipefail
echo "[40-network] a configurar vmbr0"

IFACES=/etc/network/interfaces
NIC="$(ip -o link show | awk -F': ' '/ en[a-z0-9]+:/ {print $2; exit}')"
[[ -n "$NIC" ]] || { echo "  nao encontrei a NIC fisica" >&2; exit 1; }
echo "  NIC fisica: $NIC"

if grep -q 'bridge-vlan-aware yes' "$IFACES"; then
  echo "  vmbr0 ja e VLAN-aware — nada a fazer"
else
  cp -n "$IFACES" "${IFACES}.orig" || true
  BAK="${IFACES}.bak.$(date +%s)"
  cp "$IFACES" "$BAK"
  echo "  copia de seguranca: $BAK"

  # Acrescenta as directivas de VLAN ao bloco existente do vmbr0, preservando
  # o endereco e o gateway que ja la estao. O bloco termina na primeira linha
  # em branco ou no inicio de outra stanza.
  awk '
    /^(auto|iface|allow-)/ && in_br { flush_br() }
    /^[[:space:]]*$/       && in_br { flush_br() }
    /^iface vmbr0[[:space:]]/       { in_br = 1 }
    { print }
    END { if (in_br) flush_br() }
    function flush_br() {
      print "    bridge-vlan-aware yes"
      print "    bridge-vids 2-4094"
      print "    bridge-pvid 1"
      in_br = 0
    }
  ' "$BAK" >"${IFACES}.new"

  # so substitui se o resultado continuar a ter o bloco do vmbr0
  grep -q '^iface vmbr0' "${IFACES}.new" || {
    echo "  resultado invalido — a abortar sem tocar em $IFACES" >&2
    rm -f "${IFACES}.new"; exit 1; }

  mv "${IFACES}.new" "$IFACES"
  ifreload -a
  echo "  vmbr0 agora e VLAN-aware"
fi

# desligar offloads com problemas conhecidos nos Realtek 8125
cat >/etc/network/if-up.d/rtl8125-offload <<EOF
#!/bin/sh
[ "\$IFACE" = "$NIC" ] || exit 0
/sbin/ethtool -K "$NIC" tso off gso off gro off 2>/dev/null || true
exit 0
EOF
chmod +x /etc/network/if-up.d/rtl8125-offload

echo "[40-network] ok"
ip -br addr show vmbr0
