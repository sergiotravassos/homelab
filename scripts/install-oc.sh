#!/usr/bin/env bash
# oc e openshift-install nao estao no registo do mise. Este script instala a
# versao declarada em openshift/install/VERSION, para que a ferramenta local e
# a do cluster nunca divirjam.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"${ROOT}/openshift/install/VERSION")"
DEST="${HOME}/.local/bin"
MIRROR="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PKG_OC="openshift-client-mac-arm64.tar.gz"
                PKG_INST="openshift-install-mac-arm64.tar.gz" ;;
  Darwin-x86_64) PKG_OC="openshift-client-mac.tar.gz"
                 PKG_INST="openshift-install-mac.tar.gz" ;;
  Linux-x86_64) PKG_OC="openshift-client-linux.tar.gz"
                PKG_INST="openshift-install-linux.tar.gz" ;;
  *) echo "plataforma nao suportada: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for pkg in "$PKG_OC" "$PKG_INST"; do
  echo "==> ${pkg} (${VERSION})"
  curl -fsSL "${MIRROR}/${pkg}" -o "${TMP}/${pkg}"
  tar -xzf "${TMP}/${pkg}" -C "$TMP"
done

install -m 0755 "${TMP}/oc" "${DEST}/oc"
install -m 0755 "${TMP}/openshift-install" "${DEST}/openshift-install"

echo "==> instalado em ${DEST}"
"${DEST}/oc" version --client
"${DEST}/openshift-install" version | head -1

case ":${PATH}:" in
  *":${DEST}:"*) ;;
  *) echo; echo "AVISO: ${DEST} nao esta no PATH." ;;
esac
