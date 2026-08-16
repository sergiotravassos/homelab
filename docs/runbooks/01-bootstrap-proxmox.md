# Runbook 01 — Instalar e preparar o Proxmox

**Frequência:** uma vez, e depois de cada reinstalação do hipervisor.
**Duração:** ~90 minutos, dos quais 40 são o `memtest`.
**Requer:** acesso físico, monitor ligado à saída da motherboard (**não** à GPU), teclado, pen USB.

Este é o único procedimento manual do repositório. Tudo o resto nasce de código.

---

## 0. Antes de instalar

### BIOS

Entrar com `Del`. Aplicar e gravar:

| Definição | Valor |
|---|---|
| EXPO / DOCP | Perfil I (DDR5-6000 CL30) |
| SVM Mode | Enabled |
| IOMMU | Enabled |
| Above 4G Decoding | Enabled |
| Re-Size BAR Support | Enabled |
| **Primary Video Adapter** | **IGFX / Integrated** |
| CSM | Disabled |
| Secure Boot | Disabled |
| Restore on AC Power Loss | Power On |
| PBO | Disabled |

`Primary Video Adapter` em `Integrated` é o passo que faz o passthrough funcionar mais tarde. Com
`PCIe`, o host reclama a placa no arranque e o `vfio-pci` chega tarde de mais.

`Restore on AC Power Loss` em `Power On` para o nó voltar sozinho depois de um corte.

### Memória

Arrancar `memtest86+` a partir de uma pen e deixar **uma passagem completa**. Com EXPO activo,
memória instável dá corrupção silenciosa que só aparece semanas depois, sob a forma de um ZFS a
reportar erros de checksum sem causa aparente.

Se falhar: baixar para DDR5-5600 e repetir. Um lab estável a 5600 vale mais do que um lab instável a
6000.

---

## 1. Instalar o Proxmox VE

1. Gravar a ISO oficial numa pen (`dd` ou Balena Etcher).
2. Arrancar. **Install Proxmox VE (Graphical)**.
3. Sistema de ficheiros: **`zfs (RAID0)`** no NVMe de 2 TB.
   Em **Options**:
   | Campo | Valor |
   |---|---|
   | `ashift` | `12` |
   | `compress` | `zstd` |
   | `checksum` | `on` |
   | `copies` | `1` |
4. País, fuso `Europe/Lisbon`, teclado.
5. Palavra-passe de `root` e e-mail para os alertas.
6. Rede — **valores da fase 1, na LAN de casa**:
   | Campo | Valor |
   |---|---|
   | Interface | a NIC Realtek |
   | Hostname | `forge.lab.home.arpa` |
   | IP | `192.168.1.10/24` |
   | Gateway | `192.168.1.1` |
   | DNS | `192.168.1.1` |

> A migração para `10.10.10.10` na VLAN 10 acontece no passo 4, **na consola local**. Fazê-la agora,
> pela rede, corta o acesso a meio.

7. Instalar, retirar a pen, reiniciar.

---

## 2. Primeiro acesso

Abrir `https://192.168.1.10:8006` e aceitar o certificado. Ignorar o aviso de subscrição.

Chave SSH a partir do Mac:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.10
ssh root@192.168.1.10 'pveversion && zpool status rpool'
```

---

## 3. `make bootstrap`

A partir do Mac, com o repositório clonado:

```bash
cd homelab
export PVE_HOST=192.168.1.10
make bootstrap
```

O que corre, na ordem em que corre — ver [`bootstrap/proxmox/`](../../bootstrap/proxmox/):

| Passo | Ficheiro | O que faz |
|---|---|---|
| 1 | `10-repos.sh` | Troca o repositório `enterprise` pelo `no-subscription`; actualiza |
| 2 | `20-iommu.sh` | Parâmetros de kernel `amd_iommu=on iommu=pt`; regenera o initramfs |
| 3 | `30-zfs-tuning.sh` | Limita a ARC; `atime=off`; agenda o `scrub` mensal |
| 4 | `40-network.sh` | Escreve `/etc/network/interfaces` com o bridge VLAN-aware |
| 5 | `50-api-token.sh` | Cria o utilizador e o token para o OpenTofu, com privilégio mínimo |
| 6 | `60-hardening.sh` | SSH sem palavra-passe, `fail2ban`, `unattended-upgrades`, alertas por e-mail |

Reiniciar e confirmar:

```bash
ssh root@192.168.1.10 'dmesg | grep -i -e AMD-Vi -e "IOMMU enabled"'
ssh root@192.168.1.10 'cat /sys/module/zfs/parameters/zfs_arc_max'
```

---

## 4. Preparar a GPU para passthrough

Procedimento completo, incluindo o apuramento dos IDs e dos grupos IOMMU:
**[`../gpu-passthrough.md`](../gpu-passthrough.md)**.

Resumo:

```bash
# apurar os IDs reais desta máquina
lspci -nn | grep -i -e VGA -e Audio

# escrever em ansible/inventories/lab/group_vars/proxmox.yml → vfio_device_ids
# depois, do Mac:
make configure-host
```

Verificação — e é única:

```bash
lspci -nnk -d 1002:      # tem de dizer "Kernel driver in use: vfio-pci"
```

Se disser `amdgpu`, **parar aqui**. Rever o `Primary Video Adapter` na BIOS e regenerar o initramfs.
Continuar com o `amdgpu` agarrado à placa não dá erro — dá um ecrã preto no guest, mais tarde, sem
pista nenhuma.

---

## 5. Migrar para a VLAN de gestão

**Só depois de o switch estar configurado.** Fazer **na consola local**, com monitor e teclado
ligados à máquina.

```bash
# na consola física do forge
vi /etc/network/interfaces      # trocar para 10.10.10.10/24, gateway 10.10.10.1
systemctl restart networking
ip -br a && ping -c2 10.10.10.1
```

Depois, do Mac: actualizar `PVE_HOST` no `.envrc` e o `~/.ssh/config`.

Se a rede não voltar, o acesso continua a existir — é para isso que o monitor está ligado.

---

## 6. Token de API para o OpenTofu

O `50-api-token.sh` cria `tofu@pve!homelab` com privilégio mínimo. Guardar o segredo no Keychain,
nunca em ficheiro:

```bash
security add-generic-password -a "$USER" -s homelab-proxmox-token -w
# colar o segredo quando pedido
```

Validar:

```bash
make plan     # tem de listar recursos a criar, sem erro de autenticação
```

---

## 7. Lista de verificação final

- [ ] `memtest86+` passou uma vez com EXPO
- [ ] `zpool status rpool` sem erros
- [ ] `dmesg` confirma IOMMU activo
- [ ] `lspci -nnk -d 1002:` diz `vfio-pci`
- [ ] ARC limitada e persistente após reinício
- [ ] `vmbr0` VLAN-aware, gestão alcançável
- [ ] Token de API funcional, `make plan` corre
- [ ] SSH só por chave; `fail2ban` activo
- [ ] Alertas por e-mail a chegar (`zed` e `pvemail`)
- [ ] Consumo em `idle` medido e registado

Feito isto, o hipervisor está pronto e o resto do lab é `tofu apply`.

---

## Problemas conhecidos

| Sintoma | Causa | Solução |
|---|---|---|
| Não arranca depois de activar o EXPO | Memória instável | Limpar CMOS; tentar DDR5-5600 |
| Sem imagem depois da instalação | Monitor ligado à GPU, não à motherboard | Trocar o cabo para a saída da motherboard |
| `IOMMU: Default domain type: Translated` | `iommu=pt` não aplicado | Confirmar `/etc/kernel/cmdline` ou GRUB, correr `proxmox-boot-tool refresh` |
| Sem rede após o passo 5 | Nome da interface mudou | Consola local; `ip -br link` e corrigir `bridge-ports` |
| ARC volta a subir após reinício | Só aplicado em runtime | `/etc/modprobe.d/zfs.conf` + `update-initramfs -u -k all` |
