# Hardware

Nó único, nome `forge`. Montado para correr permanentemente, em silêncio, com folga para uma carga
pesada de cada vez — nunca para todas.

## Lista de material

| Componente | Modelo | Notas de operação |
|---|---|---|
| CPU | AMD Ryzen 9 9950X3D | 16C / 32T, dois CCDs assimétricos. Ver [Topologia de CPU](#topologia-de-cpu) |
| Motherboard | ASUS ROG Strix B850-I Gaming WiFi | Mini-ITX AM5. 2 × DIMM, 2 × M.2, 1 × PCIe 5.0 x16 ligado ao CPU |
| RAM | Kingston FURY Beast 64 GB (2 × 32 GB) DDR5-6000 CL30 | Perfil EXPO. Ver [Memória](#memória) |
| Armazenamento | Samsung 990 PRO 2 TB (MZ-V9P1T0BW) | PCIe 4.0 x4, 1 200 TBW. Pool ZFS única |
| GPU | Sapphire PULSE Radeon RX 9060 XT 16 GB | RDNA 4. Passada inteira à VM `bazzite` |
| Rede | Realtek RTL8125 2.5 GbE (integrada) | Uplink único. Wi-Fi 7 não usado para tráfego de lab |
| Alimentação | Corsair SF850 (2024) 850 W SFX 80+ Platinum | Ventoinha parada abaixo de ~40 % de carga |
| Arrefecimento | Thermalright AXP120-X67 | Ar, low-profile. Sem bomba a envelhecer |
| Caixa | Fractal Design Ridge | SFF vertical, GPU em câmara térmica separada |

## Topologia de CPU

O 9950X3D não é um CPU homogéneo, e tratá-lo como tal é o erro mais comum com esta peça.

| | CCD 0 | CCD 1 |
|---|---|---|
| Núcleos | 8C / 16T | 8C / 16T |
| CPUs no Linux | `0–7` + SMT `16–23` | `8–15` + SMT `24–31` |
| Cache L3 | 32 MB + 64 MB empilhada | 32 MB |
| Ponto forte | latência de memória em cargas com working set grande | frequência sustentada |
| Atribuído a | `bazzite` | `ocp-sno`, `devbox`, restantes guests |

**Confirmar a numeração no metal antes de fixar seja o que for.** A associação entre CCD e índice de
CPU não é garantida por contrato:

```bash
lscpu -e=CPU,CORE,SOCKET,NODE,CACHE
cat /sys/devices/system/cpu/cpu0/cache/index3/size   # o CCD com V-Cache reporta ~96M
cat /sys/devices/system/cpu/cpu8/cache/index3/size   # o outro reporta ~32M
lstopo-no-graphics --of console                      # exige hwloc
```

O valor apurado vai para `ansible/inventories/lab/group_vars/all.yml` em `cpu_ccd0_cpus` e
`cpu_ccd1_cpus`, e é daí que o OpenTofu e o Ansible derivam o `cpuset` de cada guest. Nenhum ficheiro
deste repositório traz a numeração escrita à mão.

### Porque é que o pinning importa

Num X3D de dois CCDs, deixar o escalonador migrar uma thread entre dies significa perder a cache
empilhada e pagar a travessia do Infinity Fabric. Para um jogo, isso é *stutter*. Para uma compilação
GraalVM `native-image`, é ruído nas medições. Fixar a `bazzite` no CCD 0 e tudo o resto no CCD 1
resolve os dois problemas com uma linha de configuração.

## Memória

64 GB em dois módulos, os dois slots ocupados. É o recurso que define a forma do lab inteiro —
ver **[capacity.md](capacity.md)**.

- Perfil EXPO activo. Em AM5, DDR5-6000 CL30 com dois módulos de face simples é o ponto habitual de
  estabilidade; validar com `memtest86+` antes de dar o lab por assente.
- A ARC do ZFS é limitada explicitamente. Sem limite, o ZFS reclama até metade da RAM e o host entra
  em competição com os guests exactamente quando eles mais precisam.
- Sem ECC. É consumidor, e o repositório assume-o: os backups são a rede de segurança, não a memória.

## Armazenamento

Um disco. É o ponto de falha único mais visível deste lab e está assumido como tal.

```
rpool (ZFS, ashift=12, compression=zstd, atime=off)
├── rpool/ROOT/pve-1      sistema do Proxmox
├── rpool/data            zvols dos guests
└── rpool/var-lib-vz      ISOs, templates, dumps
```

Decisões e o que se perde com cada uma em [`adr/0006-armazenamento-zfs-disco-unico.md`](adr/0006-armazenamento-zfs-disco-unico.md).

Resumo:

- **ZFS num disco só** não dá redundância, mas dá *checksums*, snapshots baratos e `zfs send` para o
  backup. A alternativa (LVM-thin) é mais leve em escrita e não dá nada disto.
- **Amplificação de escrita.** O 990 PRO tem 1 200 TBW. Com `atime=off`, `zstd` e `volblocksize` de
  16 K nos zvols, o desgaste esperado de um lab está confortavelmente dentro da garantia.
- **O segundo slot M.2 está livre.** O primeiro upgrade planeado é separar o boot dos dados dos
  guests. Não urge — urge é o backup existir.

## Rede física

Uma NIC de 2.5 GbE. Toda a segmentação é 802.1Q sobre esse único link, contra um switch gerível.
Ver **[network.md](network.md)** e [`adr/0005-vlans-com-switch-gerivel.md`](adr/0005-vlans-com-switch-gerivel.md).

O Wi-Fi 7 fica desligado para tráfego de lab: um bridge sem fios não faz VLAN tagging de forma
previsível e não vale o depuramento. O Bluetooth é passado por USB à `bazzite`, para os comandos.

## Orçamento térmico e energia

O nó não desliga. Isso muda as prioridades face a uma máquina de jogos normal.

- **PBO desligado**, com limite de PPT conservador. Perde-se pouco numa compilação e ganha-se um
  ventilador que não muda de tom.
- Alvos: **< 65 °C** com o perfil `idle`, **< 90 °C** num pico de `native-image`.
- Governor `performance` no host — o `ondemand` interage mal com VMs sensíveis a latência, e o ganho
  em consumo não compensa.
- O consumo em `idle` é o número que interessa, não o pico. É medido e registado em
  [`runbooks/`](runbooks/) assim que o hardware estiver montado.

## O que o hardware decide pela arquitectura

Quatro limitações físicas explicam quase todas as decisões deste repositório:

| Limitação | Consequência |
|---|---|
| 1 GPU dedicada + 1 iGPU | A dGPU pertence a uma VM de cada vez. Não há gaming e compute GPU em paralelo |
| 1 NIC | Segmentação tem de ser 802.1Q num switch gerível, não em placas separadas |
| 64 GB em 2 slots | Nem tudo liga ao mesmo tempo. Daí os perfis de memória |
| 1 disco | O backup deixa de ser boa prática e passa a ser requisito |
