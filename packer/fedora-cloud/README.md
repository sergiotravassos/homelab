# Template Fedora cloud

Constroi o template a partir do qual o `devbox` e clonado.

## Passo previo, manual e unico

O plugin `proxmox-clone` clona uma VM existente; nao descarrega imagens. E preciso
criar a VM semente (VMID 9999) a partir do qcow2 oficial do Fedora, uma vez:

```bash
# no host Proxmox
VER=42
cd /var/lib/vz/template/iso
curl -fLO "https://download.fedoraproject.org/pub/fedora/linux/releases/${VER}/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-${VER}-1.1.x86_64.qcow2"

qm create 9999 --name fedora-seed --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single \
  --ostype l26 --machine q35 --bios ovmf

qm importdisk 9999 Fedora-Cloud-Base-Generic-${VER}-1.1.x86_64.qcow2 local-zfs
qm set 9999 --scsi0 local-zfs:vm-9999-disk-0 --boot order=scsi0
qm set 9999 --ide2 local-zfs:cloudinit --serial0 socket --vga serial0
qm set 9999 --efidisk0 local-zfs:0,efitype=4m,pre-enrolled-keys=0
qm set 9999 --ciuser sergio --sshkeys ~/.ssh/authorized_keys
```

## Construir

```bash
make template
```

Produz o template com VMID 9000, referido em `tofu/envs/lab/terraform.tfvars`
por `fedora_template_vm_id`.

## Porque nao kickstart

O Fedora publica imagens cloud oficiais, testadas e assinadas. Reconstrui-las a
partir de um kickstart daria o mesmo resultado com mais superficie para partir.
O Packer aqui so acrescenta o `qemu-guest-agent` e limpa o estado do cloud-init.
