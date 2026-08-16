#!/usr/bin/env bash
# Utilizador e token de API para o OpenTofu, com privilegio minimo.
# O segredo e impresso UMA vez: guardar no Keychain, nunca em ficheiro.
set -euo pipefail
echo "[50-api-token] a preparar o acesso do OpenTofu"

USER_ID="tofu@pve"
TOKEN_ID="homelab"
ROLE="TofuProvisioner"

# Papel com o minimo necessario para criar guests, discos, redes e passthrough.
# Sem Sys.PowerMgmt, sem Realm.Allocate, sem Permissions.Modify.
PRIVS="VM.Allocate,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,\
VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,\
VM.Config.Options,VM.Monitor,VM.Audit,VM.PowerMgmt,\
Datastore.AllocateSpace,Datastore.Audit,Datastore.AllocateTemplate,\
SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Pool.Allocate,Pool.Audit"

if pveum role list --output-format json | jq -e --arg r "$ROLE" '.[]|select(.roleid==$r)' >/dev/null; then
  pveum role modify "$ROLE" --privs "$PRIVS"
  echo "  papel $ROLE actualizado"
else
  pveum role add "$ROLE" --privs "$PRIVS"
  echo "  papel $ROLE criado"
fi

if ! pveum user list --output-format json | jq -e --arg u "$USER_ID" '.[]|select(.userid==$u)' >/dev/null; then
  pveum user add "$USER_ID" --comment "OpenTofu — gerido pelo repo homelab"
  echo "  utilizador $USER_ID criado"
fi

pveum acl modify / --users "$USER_ID" --roles "$ROLE"

if pveum user token list "$USER_ID" --output-format json 2>/dev/null | \
     jq -e --arg t "$TOKEN_ID" '.[]|select(.tokenid==$t)' >/dev/null; then
  echo
  echo "  O token ${USER_ID}!${TOKEN_ID} ja existe."
  echo "  O segredo so e mostrado na criacao. Para rodar:"
  echo "     pveum user token remove ${USER_ID} ${TOKEN_ID} && bash 50-api-token.sh"
else
  echo
  echo "  ================= GUARDAR AGORA — nao volta a aparecer ================="
  pveum user token add "$USER_ID" "$TOKEN_ID" --privsep 0 --output-format json | jq -r '.value'
  echo "  ======================================================================="
  echo
  echo "  No Mac:"
  echo "     security add-generic-password -a \"\$USER\" -s homelab-proxmox-token -w"
fi

echo "[50-api-token] ok"
