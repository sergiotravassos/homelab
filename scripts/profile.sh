#!/usr/bin/env bash
# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Liga e desliga conjuntos de guests conforme o perfil de memória escolhido.
#  PORQUE EXISTE  A soma dos guests pede 80 GB e a máquina tem 64. Este script é o mecanismo
#                 que impede o lab de entrar em falta de memória.
#  SE TIRARES     Ligas tudo, a máquina fica sem RAM, e o oom-killer escolhe por ti — e
#                 escolhe sempre mal.
#  ONDE APRENDER  docs/percurso.md — etapa 2 para o contexto, docs/capacity.md para as contas
# ──────────────────────────────────────────────────────────────────────────────
#
#  Duas decisões dentro deste script que valem a pena:
#
#  1. PÁRA antes de arrancar. Liberta memória primeiro, senão o guest novo pede
#     RAM que ainda está presa no antigo.
#
#  2. Arranca por ordem de VMID. Não é arbitrário: o ocp-sno (120) sobe antes da
#     devbox (130) porque não tolera ballooning e falha pior se não conseguir
#     a memória que pediu. Quem chega primeiro é servido.

set -euo pipefail

PVE_HOST="${PVE_HOST:-10.10.10.10}"
PVE_USER="${PVE_USER:-root}"
SSH=(ssh -o BatchMode=yes "${PVE_USER}@${PVE_HOST}")

# vmid:tipo:nome:ram_gb
GUESTS=(
  "100:qm:opnsense-lab:2"
  "110:qm:haos:4"
  "120:qm:ocp-sno:24"
  "130:qm:devbox:16"
  "140:qm:bazzite:16"
  "200:pct:kafka:4"
  "201:pct:postgres:4"
  "202:pct:registry:2"
)

profile_members() {
  case "$1" in
    idle)      echo "100 110" ;;
    gaming)    echo "100 110 140" ;;
    dev)       echo "100 110 130 200 201 202" ;;
    platform)  echo "100 110 120 200 201 202" ;;
    full-lab)  echo "100 110 120 130 200 201 202" ;;
    *) echo "perfil desconhecido: $1" >&2
       echo "disponiveis: idle gaming dev platform full-lab" >&2
       exit 2 ;;
  esac
}

meta() { # $1=vmid $2=campo(2=tipo 3=nome 4=ram)
  local g
  for g in "${GUESTS[@]}"; do
    [[ "${g%%:*}" == "$1" ]] && { echo "$g" | cut -d: -f"$2"; return; }
  done
}

running_ids() {
  {
    "${SSH[@]}" "qm list  | awk 'NR>1 && \$3==\"running\" {print \$1}'"
    "${SSH[@]}" "pct list | awk 'NR>1 && \$2==\"running\" {print \$1}'"
  } 2>/dev/null | sort -n
}

cmd_status() {
  local total=0 running
  running="$(running_ids || true)"
  printf '%-6s %-16s %6s  %s\n' VMID NOME RAM ESTADO
  for g in "${GUESTS[@]}"; do
    IFS=: read -r id _ name ram <<<"$g"
    if grep -qx "$id" <<<"$running"; then
      printf '%-6s %-16s %5sG  ligado\n' "$id" "$name" "$ram"
      total=$((total + ram))
    else
      printf '%-6s %-16s %5sG  parado\n' "$id" "$name" "$ram"
    fi
  done
  echo "---"
  echo "host + ARC:            6G"
  echo "guests ligados:       ${total}G"
  echo "comprometido:         $((total + 6))G de 64G"
}

cmd_apply() {
  local profile="$1" wanted running
  wanted="$(profile_members "$profile")"
  running="$(running_ids || true)"

  echo "==> perfil ${profile}"

  # parar primeiro, para libertar memoria antes de pedir mais
  for g in "${GUESTS[@]}"; do
    IFS=: read -r id type name _ <<<"$g"
    if grep -qx "$id" <<<"$running" && ! grep -qw "$id" <<<"$wanted"; then
      echo "  parar   ${name} (${id})"
      "${SSH[@]}" "$type shutdown $id --timeout 120" || \
        "${SSH[@]}" "$type stop $id"
    fi
  done

  # arrancar por ordem de vmid: opnsense e haos primeiro, ocp-sno antes do devbox
  for id in $wanted; do
    if ! grep -qx "$id" <<<"$running"; then
      echo "  arrancar $(meta "$id" 3) (${id})"
      "${SSH[@]}" "$(meta "$id" 2) start $id"
      sleep 5
    fi
  done

  echo "==> feito"
  cmd_status
}

case "${1:-status}" in
  status) cmd_status ;;
  apply)  cmd_apply "${2:?indica o perfil}" ;;
  *) echo "uso: $0 {status|apply <perfil>}" >&2; exit 2 ;;
esac
