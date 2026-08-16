# Rede

Uma placa de rede física, seis domínios de broadcast, um router que não é o router de casa.

Ver o desenho: **[diagrams/02-network.svg](diagrams/02-network.svg)**.

## Princípios

1. **O router doméstico não é gerido por este repositório.** Se o lab ficar em baixo — e vai ficar,
   é para isso que serve — a casa continua com Internet. Um homelab que derruba o Wi-Fi da família
   é um homelab que deixa de ser autorizado.
2. **Segmentação por VLAN, não por placa.** Há uma NIC. O switch gerível faz o trabalho.
3. **Negar por omissão entre VLANs.** O que passa está escrito em `ansible/` e revisto em PR.
4. **O host não roteia.** O Proxmox tem um bridge VLAN-aware e mais nada. O encaminhamento é do
   OPNsense, que é uma VM como as outras e cujo estado está em Git.

## Plano de endereçamento

Supernet do laboratório: `10.10.0.0/16`. Uma `/24` por VLAN, com espaço de sobra para crescer.

| VLAN | Nome | Sub-rede | Gateway | DHCP | Notas |
|---:|---|---|---|---|---|
| — | `untagged` (PVID 1) | `192.168.1.0/24` | `192.168.1.1` | router de casa | Perna WAN do OPNsense; é por aqui que o MacBook entra |
| 10 | `MGMT` | `10.10.10.0/24` | `10.10.10.1` | estático | Plano de gestão. Nunca alcançável a partir de IOT |
| 20 | `PLATFORM` | `10.10.20.0/24` | `10.10.20.1` | estático | Workloads e serviços de dados |
| 30 | `IOT` | `10.10.30.0/24` | `10.10.30.1` | OPNsense | Firmware de terceiros. O segmento não-confiável |
| 40 | `GAMING` | `10.10.40.0/24` | `10.10.40.1` | OPNsense | Bazzite |
| 50 | `DEV` | `10.10.50.0/24` | `10.10.50.1` | OPNsense | Bancada de desenvolvimento |

### Endereços fixos

| Anfitrião | Endereço | VLAN |
|---|---|---:|
| Switch (gestão) | `10.10.10.2` | 10 |
| `forge` — Proxmox | `10.10.10.10` | 10 |
| `pbs` — Proxmox Backup Server | `10.10.10.11` | 10 |
| `ocp-sno` — API e nó | `10.10.20.20` | 20 |
| `kafka` | `10.10.20.21` | 20 |
| `postgres` | `10.10.20.22` | 20 |
| `registry` | `10.10.20.23` | 20 |
| `haos` | `10.10.30.30` | 30 |
| `bazzite` | `10.10.40.40` | 40 |
| `devbox` | `10.10.50.50` | 50 |

A convenção é simples e propositadamente aborrecida: o último octeto repete o número da VLAN para o
serviço principal do segmento, e sobe a partir daí.

## Configuração do switch

Porta 1 é o trunk para o `forge`:

```
porta 1   trunk    tagged 10,20,30,40,50   untagged/PVID 1
portas 2-7  access  uma VLAN cada (IoT, sala, bancada, conforme necessário)
porta 8   access   VLAN 10, para gestão de emergência
```

A VLAN nativa continua a ser a LAN de casa, sem etiqueta. É deliberado: dá ao OPNsense uma perna WAN
sem interface adicional e mantém o acesso de recuperação a funcionar mesmo com as VLANs mal
configuradas.

## Proxmox

O bridge é VLAN-aware e o host não tem interfaces por VLAN — só a de gestão.

```ini
# /etc/network/interfaces  (gerido por bootstrap/proxmox/)
auto lo
iface lo inet loopback

iface enp*s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.10.10.10/24
    gateway 10.10.10.1
    bridge-ports enp*s0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
    bridge-pvid 1
```

Cada guest declara a sua etiqueta no OpenTofu, em `network_device.vlan_id`. Não há bridges por VLAN,
não há `vmbr1`, `vmbr2` — um bridge, etiquetas nos guests.

> **Ordem de operações.** Mudar o endereço de gestão do Proxmox pela rede é a forma mais rápida de
> ficar sem acesso. O passo está no runbook, feito na consola local, com a iGPU ligada a um monitor.

## Router e firewall do laboratório

`opnsense-lab` é uma VM com uma perna untagged (WAN, na LAN de casa) e uma sub-interface por VLAN,
sempre no `.1`. Faz DHCP, DNS e firewall inter-VLAN.

Matriz de fluxo — a origem está nas linhas, o destino nas colunas:

| ↓ de / → para | MGMT | PLATFORM | IOT | GAMING | DEV | Internet |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **MGMT** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **PLATFORM** | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **IOT** | ❌ | ❌ | ✅ | ❌ | ❌ | ⚠️ limitada |
| **GAMING** | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| **DEV** | ⚠️ só SSH e a UI do Proxmox | ✅ | ❌ | ❌ | ✅ | ✅ |
| **LAN de casa** | ⚠️ só a UI do Proxmox | ⚠️ só os *routes* do OpenShift | ❌ | ⚠️ Sunshine | ⚠️ SSH | — |

Ler assim: a `DEV` é a única VLAN de onde se trabalha, e é por isso a única com rota aberta para a
`PLATFORM`. A `IOT` não fala com nada — se uma lâmpada for comprometida, chega ali e para.

## DNS

Domínio interno: **`lab.home.arpa`**, resolvido pelo Unbound do OPNsense.

A escolha não é cosmética. `.local` é reservado para mDNS e provoca resoluções erráticas em macOS e
em contentores; um TLD inventado (`.lab`, `.home`) arrisca colidir com um gTLD real amanhã.
`home.arpa` é o nome reservado pela RFC 8375 exactamente para isto.

Registos necessários para o OpenShift SNO — sem eles a instalação não completa:

| Registo | Tipo | Valor |
|---|---|---|
| `api.sno.lab.home.arpa` | A | `10.10.20.20` |
| `api-int.sno.lab.home.arpa` | A | `10.10.20.20` |
| `*.apps.sno.lab.home.arpa` | A | `10.10.20.20` |

No MacBook, em vez de mudar o DNS do sistema, basta delegar o domínio:

```bash
sudo mkdir -p /etc/resolver
printf 'nameserver 10.10.10.1\n' | sudo tee /etc/resolver/home.arpa
```

Assim o lab resolve sem mexer no resto da resolução da máquina.

## Acesso remoto

Fora de casa, o acesso é por [Tailscale](https://tailscale.com/), com um nó subnet router no OPNsense
a anunciar `10.10.0.0/16`. Sem portas abertas no router doméstico, sem DDNS, sem VPN a manter.

O que **não** é exposto à Internet: a UI do Proxmox, a API do OpenShift, o Home Assistant. Se algum
dia houver exposição pública, será por um único *reverse proxy* com autenticação à frente, e passará
por um ADR.

## Fase 1 — antes do switch gerível

O switch é a única peça em falta. Até chegar, tudo colapsa para a VLAN nativa: os guests ficam sem
etiqueta na LAN de casa, o OPNsense fica desligado e o DNS do lab passa por um LXC com `dnsmasq`.

O repositório suporta os dois modos com uma variável — `network_mode: flat | vlan` em
`ansible/inventories/lab/group_vars/all.yml`. O caminho e o custo de cada modo estão em
[`adr/0005-vlans-com-switch-gerivel.md`](adr/0005-vlans-com-switch-gerivel.md).
