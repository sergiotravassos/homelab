#!/usr/bin/env bash
# Confirma que os backups correram e que sao legiveis. Falha ruidosamente:
# um backup silenciosamente parado e o pior modo de falha possivel.
set -uo pipefail

PBS_REPO="${PBS_REPO:-pbs@pbs@10.10.10.11:homelab}"
MAX_AGE_H="${MAX_AGE_H:-26}"
rc=0

echo "== verificacao de backups =="

echo "-- tarefas de vzdump nas ultimas ${MAX_AGE_H}h"
recent=$(pvesh get /cluster/tasks --output-format json 2>/dev/null \
  | jq -r --argjson h "$MAX_AGE_H" \
      '.[] | select(.type=="vzdump") | select(.starttime > (now - ($h*3600))) | "\(.id) \(.status)"')

if [[ -z "$recent" ]]; then
  echo "  FALHA: nenhuma tarefa de vzdump nas ultimas ${MAX_AGE_H}h"
  rc=1
else
  while read -r id status; do
    if [[ "$status" == "OK" ]]; then
      echo "  OK    $id"
    else
      echo "  FALHA $id -> $status"
      rc=1
    fi
  done <<<"$recent"
fi

echo "-- snapshots no PBS"
if command -v proxmox-backup-client >/dev/null 2>&1; then
  if proxmox-backup-client snapshot list --repository "$PBS_REPO" --output-format text 2>/dev/null | tail -n +2; then
    :
  else
    echo "  FALHA: nao consegui listar os snapshots em $PBS_REPO"
    rc=1
  fi
else
  echo "  AVISO: proxmox-backup-client nao instalado neste host"
fi

echo "-- espaco no datastore"
df -h /mnt/backup 2>/dev/null || echo "  AVISO: /mnt/backup nao montado"

echo "-- snapshots ZFS recentes"
zfs list -t snapshot -o name,used,creation -s creation 2>/dev/null | tail -5

echo
if [[ "$rc" -eq 0 ]]; then
  echo "== backups verificados =="
else
  echo "== VERIFICACAO FALHOU — ver acima =="
fi
echo
echo "Lembrete: isto verifica que os backups existem e sao legiveis."
echo "Nao substitui o restauro trimestral do runbook 03, seccao 4."
exit "$rc"
