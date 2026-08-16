# Capacidade

64 GB de RAM, dois slots ocupados, e a soma de tudo o que o lab quer correr dá 80 GB. Este documento
existe porque essa conta não fecha — e a resposta não é comprar já, é desenhar em torno do limite.

Ver o desenho: **[diagrams/04-capacity.svg](diagrams/04-capacity.svg)**.

## Orçamento

| Consumidor | RAM | Notas |
|---|---:|---|
| Host Proxmox + ARC do ZFS | 6 GB | 2 GB de sistema, 4–8 GB de ARC conforme o perfil |
| `opnsense-lab` | 2 GB | fixo, sempre ligado |
| `haos` | 4 GB | fixo, sempre ligado |
| `ocp-sno` | 24 GB | sem balloon; o OpenShift lida mal com memória a desaparecer |
| `platform` (3 × LXC) | 12 GB | Kafka 4, PostgreSQL 4, registry 2, folga 2 |
| `devbox` | 16 GB | balloon 8–16 |
| `bazzite` | 16 GB | hugepages, sem balloon |
| **Total se tudo ligasse** | **80 GB** | **16 GB acima do físico** |

## Perfis

Cada perfil é um alvo do `Makefile` que arranca e pára conjuntos de guests. Não é uma sugestão —
é o mecanismo pelo qual o lab não entra em OOM.

| Perfil | RAM | Contém | Para quê |
|---|---:|---|---|
| `idle` | 12 GB | host, `opnsense-lab`, `haos` | O estado por omissão. A casa funciona, o lab dorme |
| `gaming` | 28 GB | `idle` + `bazzite` | Consola da sala |
| `dev` | 40 GB | `idle` + `devbox` + `platform` | O perfil de todos os dias: código, Kafka, PostgreSQL |
| `platform` | 48 GB | `idle` + `ocp-sno` + `platform` | Exercícios de OpenShift e GitOps |
| `full-lab` | 64 GB | `idle` + `ocp-sno` + `platform` + `devbox` | Ciclo completo, só com os ajustes abaixo |

```bash
make profile-dev        # pára o que sobra, arranca o que falta
make profile-status     # mostra o que está ligado e quanta RAM está comprometida
```

Os perfis são idempotentes: correr `make profile-dev` duas vezes não faz nada na segunda.

## O caso `full-lab`

Somado à letra, o `full-lab` dá exactamente 64 GB — ou seja, zero folga. Encostar ao tecto físico
é pedir que o `oom-killer` escolha por nós, e ele escolhe sempre mal.

Três ajustes, por esta ordem, põem o perfil em ~58 GB com 6 GB de margem:

1. **Baixar a ARC do ZFS de 8 para 4 GB.** É o ganho maior e o mais barato. Custo: menos cache de
   leitura, sensível no arranque de VMs, irrelevante depois.
   ```bash
   echo 4294967296 > /sys/module/zfs/parameters/zfs_arc_max   # runtime
   # persistente: /etc/modprobe.d/zfs.conf + update-initramfs -u
   ```
2. **Balloon do `devbox` em 8–16 GB.** Uma IDE remota e um `distrobox` parado não precisam de 16 GB.
   Numa compilação `native-image`, o balloon devolve o que for preciso.
3. **Arrancar o `ocp-sno` primeiro.** É o guest que não tolera balloon e o que falha pior se não
   conseguir a memória de que precisa. Quem chega primeiro é servido.

O que **não** se faz: activar swap para os guests. Um cluster de Kubernetes a fazer swap é um cluster
que reporta saudável enquanto entrega latências absurdas — pior do que falhar às claras.

## O caso que não existe

`gaming` + `platform` = 80 GB. Não há ajuste que resolva 16 GB em falta. A `bazzite` tem a GPU, e a
GPU não se partilha; se o OpenShift está ligado, a consola da sala está desligada. É a limitação mais
concreta deste lab e está desenhada no diagrama em vez de escondida numa nota de rodapé.

Na prática incomoda menos do que parece: as duas cargas competem pela mesma pessoa, não só pela mesma
máquina.

## CPU

O CPU não é o recurso escasso, mas o *pinning* também não é opcional — ver
[hardware.md](hardware.md#topologia-de-cpu).

| Guest | vCPU | CCD | Estratégia |
|---|---:|---|---|
| `bazzite` | 8 | 0 | `cpuset` fixo nos cores com V-Cache, sem partilha |
| `ocp-sno` | 12 | 1 | `cpuset` no CCD 1, sobrecomprometido com os restantes |
| `devbox` | 8 | 1 | idem; picos de `native-image` toleram contenção |
| `platform`, `haos`, `opnsense` | 10 no total | 1 | sem pinning, cargas leves |

Sobrecomprometer vCPU é normal e desejável. Sobrecomprometer RAM não é — daí um documento inteiro
sobre memória e três parágrafos sobre CPU.

## Armazenamento

2 TB, aproximadamente distribuídos:

| Uso | Espaço |
|---|---:|
| Proxmox + ISOs + templates | 100 GB |
| `ocp-sno` | 200 GB |
| `bazzite` (biblioteca Steam) | 250 GB |
| `devbox` | 150 GB |
| `platform`, `haos`, `opnsense` | 150 GB |
| Snapshots e dumps locais | 200 GB |
| **Livre** | **~950 GB** |

Confortável hoje. A biblioteca de jogos é o que cresce sem aviso — é o primeiro sítio a olhar quando
a pool passar dos 80 %, porque o ZFS degrada em escrita a partir daí.

## Quando comprar mais

O upgrade que resolve o problema estrutural é **2 × 48 GB (96 GB)**. Não há terceiro slot: em AM5
Mini-ITX a única saída é trocar os módulos.

Contrapartida honesta: com dois módulos de dupla face, o controlador de memória do AM5 raramente
sustenta DDR5-6000 — espera-se cair para 5600 ou abaixo. Para este lab, capacidade vale mais do que
latência: 96 GB põem o `full-lab` confortável e tornam `gaming` + `platform` possível.

Fica em aberto e sem data. O lab funciona sem isso; o que não funcionaria era fingir que já cabe.
