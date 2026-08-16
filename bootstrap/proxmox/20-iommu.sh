#!/usr/bin/env bash
# IOMMU e preparacao do vfio-pci. Os IDs da GPU sao aplicados depois, pelo Ansible,
# a partir de ansible/inventories/lab/group_vars/proxmox.yml — nunca escritos a mao aqui.
set -euo pipefail
echo "[20-iommu] a configurar IOMMU"

PARAMS="amd_iommu=on iommu=pt video=efifb:off video=vesafb:off"

if [[ -f /etc/kernel/cmdline ]]; then
  # systemd-boot (instalacao ZFS por omissao no Proxmox)
  for p in $PARAMS; do
    grep -qw -- "$p" /etc/kernel/cmdline || sed -i "1 s|\$| $p|" /etc/kernel/cmdline
  done
  proxmox-boot-tool refresh
  echo "  cmdline: $(cat /etc/kernel/cmdline)"
else
  # GRUB
  for p in $PARAMS; do
    grep -qw -- "$p" /etc/default/grub || \
      sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"|\1 $p\"|" /etc/default/grub
  done
  update-grub
  echo "  grub: $(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub)"
fi

cat >/etc/modules-load.d/vfio.conf <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
EOF

update-initramfs -u -k all

echo "[20-iommu] ok — reiniciar e confirmar com: dmesg | grep -i AMD-Vi"
echo "[20-iommu] os IDs da GPU sao ligados ao vfio-pci por 'make configure-host'"
