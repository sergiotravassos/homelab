# Passthrough da GPU

A RX 9060 XT é entregue inteira à VM `bazzite`. O host fica com a gráfica integrada do 9950X3D para
a consola. Não há partilha: esta placa não faz SR-IOV nem vGPU, e o repositório não promete o
contrário.

> **Estado: por validar no metal.** O procedimento abaixo é o desenho decidido. Os IDs de dispositivo
> e os grupos IOMMU são específicos desta máquina e têm de ser apurados no arranque — nenhum está
> escrito à mão neste repositório.

## Pré-condições

### BIOS

| Definição | Valor | Porquê |
|---|---|---|
| SVM Mode | Enabled | Virtualização AMD-V |
| IOMMU | Enabled | AMD-Vi; sem isto não há passthrough |
| Above 4G Decoding | Enabled | Requisito para mapear a BAR de 16 GB |
| Re-Size BAR Support | Enabled | Desempenho; testar desligado se houver instabilidade |
| Primary Video Adapter | IGFX / Integrated | **Crítico** — força o host a inicializar na iGPU |
| CSM | Disabled | O guest arranca em UEFI puro (OVMF) |

Se o `Primary Video Adapter` ficar em `PCIe`, o host reclama a dGPU no arranque e o `vfio-pci` chega
tarde de mais.

### Host

Parâmetros de kernel e módulos são aplicados por `bootstrap/proxmox/`:

```
amd_iommu=on iommu=pt video=efifb:off video=vesafb:off
```

`iommu=pt` (*passthrough*) mantém o DMA directo para os dispositivos do host e evita o custo de
tradução onde ele não é necessário.

## Apurar os dispositivos

Nada aqui é adivinhado. No host, depois do primeiro arranque com IOMMU activo:

```bash
# 1. Confirmar que o IOMMU está mesmo activo
dmesg | grep -i -e AMD-Vi -e IOMMU | head

# 2. Listar os grupos IOMMU e ver se a GPU está isolada
for g in /sys/kernel/iommu_groups/*/devices/*; do
  n=${g#*/iommu_groups/}; n=${n%%/*}
  printf 'grupo %-3s ' "$n"; lspci -nns "${g##*/}"
done | sort -V

# 3. Obter os IDs de fornecedor:dispositivo da placa e do seu áudio HDMI
lspci -nn | grep -i -e VGA -e Audio
```

O slot x16 do B850-I é ligado directamente ao CPU, pelo que a GPU e o seu dispositivo de áudio devem
aparecer sozinhos num grupo. **Se aparecerem acompanhados de outro dispositivo, parar aqui**: passar
um grupo partilhado corrompe o host. A solução nesse caso é mudar o dispositivo intruso de slot, não
aplicar o *patch* ACS — que desactiva um isolamento real em troca de conveniência.

Os IDs apurados vão para `ansible/inventories/lab/group_vars/proxmox.yml`:

```yaml
vfio_device_ids:
  - "1002:xxxx"   # Radeon RX 9060 XT           <- preencher no metal
  - "1002:xxxx"   # dispositivo de áudio HDMI    <- preencher no metal
```

## Ligar ao vfio-pci

```bash
# /etc/modprobe.d/vfio.conf         (gerado pelo Ansible a partir das variáveis acima)
options vfio-pci ids=1002:xxxx,1002:xxxx disable_vga=1

# /etc/modprobe.d/blacklist-gpu.conf
blacklist amdgpu
blacklist radeon
blacklist snd_hda_intel
```

Depois `update-initramfs -u -k all` e reiniciar. A verificação é única e não ambígua:

```bash
lspci -nnk -d 1002:      # "Kernel driver in use: vfio-pci"
```

Se disser `amdgpu`, o host ganhou a corrida — rever o `Primary Video Adapter` na BIOS e o
`initramfs`.

## Configuração da VM

Declarada em `tofu/envs/lab/bazzite.tf`. O essencial:

| Definição | Valor | Porquê |
|---|---|---|
| Máquina | `q35` | Topologia PCIe real; `i440fx` não serve para passthrough |
| BIOS | `ovmf` (UEFI) | Requisito das GPU modernas |
| EFI disk | com `pre-enrolled-keys = false` | Evita conflitos de Secure Boot com os drivers |
| CPU type | `host` | Expõe as instruções todas ao guest |
| `hostpci0` | GPU, `pcie=1`, `x-vga=1` | Função completa da placa |
| Balloon | `0` | Desligado: memória fixa é requisito para hugepages |
| Hugepages | `1024` (1 GB) | Reduz a pressão de TLB, mensurável em jogos |

Passa-se também um controlador USB inteiro, não portas individuais — assim os comandos podem ser
ligados e desligados a quente sem tocar na configuração:

```bash
lsusb -t                        # identificar o controlador traseiro
lspci -nn | grep -i usb         # obter o endereço PCI
```

## Saída de vídeo e som

O HDMI da placa vai directamente à televisão. O vídeo não passa pela rede e não há latência de
compressão — é a razão de existir do passthrough.

Para jogar noutro sítio da casa, [Sunshine](https://github.com/LizardByte/Sunshine) corre na
`bazzite` e o Moonlight no cliente. Aí sim há rede envolvida, e é aceitável porque a codificação é
feita pela própria GPU.

## Problemas conhecidos

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| Ecrã preto no guest, host vivo | Host reclamou a dGPU | Confirmar `vfio-pci` em `lspci -nnk`; rever BIOS |
| VM arranca uma vez e falha ao reiniciar | *Reset bug* da GPU | Testar reinício a frio; a RDNA 4 costuma repor bem, mas confirmar antes de assumir |
| Código 43 ou driver instável | Resizable BAR ou MSI | Desligar Re-Size BAR e testar; reactivar depois de estabilizar |
| Sem áudio pelo HDMI | Função de áudio não passada | Passar as duas funções da placa, não só a de vídeo |
| Host cai ao arrancar a VM | Grupo IOMMU partilhado | **Não usar o patch ACS.** Mudar o dispositivo intruso de slot |

## O que isto custa

A `bazzite` tem de estar desligada para qualquer outra coisa usar a GPU, e não há outra coisa — o
lab não tem cargas de compute GPU planeadas. Se um dia houver (inferência local de LLM é o candidato
óbvio), a escolha será entre reiniciar a VM ou comprar uma segunda placa, e não há um slot livre para
a segunda. Fica registado em [`adr/0004-passthrough-da-gpu.md`](adr/0004-passthrough-da-gpu.md).
