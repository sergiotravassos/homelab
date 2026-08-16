#!/usr/bin/env bash
# Afinacao do ZFS. A ARC compete com os guests pela memoria — o recurso escasso.
# Ver docs/capacity.md
set -euo pipefail
echo "[30-zfs] a afinar a rpool"

ARC_MAX_GB="${ARC_MAX_GB:-8}"
ARC_MIN_GB="${ARC_MIN_GB:-2}"
ARC_MAX=$((ARC_MAX_GB * 1024 * 1024 * 1024))
ARC_MIN=$((ARC_MIN_GB * 1024 * 1024 * 1024))

cat >/etc/modprobe.d/zfs.conf <<EOF
# ARC limitada: sem isto o ZFS reclama ate metade da RAM e entra em competicao
# com os guests exactamente quando eles mais precisam.
options zfs zfs_arc_max=${ARC_MAX}
options zfs zfs_arc_min=${ARC_MIN}
EOF

# aplicar tambem em runtime, para nao exigir reinicio imediato
echo "$ARC_MAX" >/sys/module/zfs/parameters/zfs_arc_max
echo "$ARC_MIN" >/sys/module/zfs/parameters/zfs_arc_min

zfs set atime=off rpool
zfs set compression=zstd rpool
zfs set xattr=sa rpool
zfs set relatime=off rpool

# scrub mensal, ao domingo, fora de horas
cat >/etc/cron.d/zfs-scrub <<'EOF'
0 4 1-7 * 0 root /usr/sbin/zpool scrub rpool
EOF

# alertas de eventos ZFS por e-mail
sed -i 's/^ZED_EMAIL_ADDR=.*/ZED_EMAIL_ADDR="root"/' /etc/zfs/zed.d/zed.rc 2>/dev/null || true
sed -i 's/^#\?ZED_NOTIFY_VERBOSE=.*/ZED_NOTIFY_VERBOSE=1/' /etc/zfs/zed.d/zed.rc 2>/dev/null || true
systemctl restart zfs-zed 2>/dev/null || true

update-initramfs -u -k all

echo "[30-zfs] ARC limitada a ${ARC_MAX_GB}G"
zfs get -H -o property,value atime,compression rpool
