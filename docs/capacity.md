# Capacidade

64 GB de RAM, dois slots ocupados, e a soma de tudo o que o lab quer correr dá 83 GB. Este documento
existe porque essa conta não fecha — e a resposta não é comprar já, é desenhar em torno do limite.

Ver o desenho: **[diagrams/04-capacity.svg](diagrams/04-capacity.svg)**.

## Orçamento

| Consumidor | RAM | Notas |
|---|---:|---|
| Host Proxmox + ARC do ZFS | 6 GB | 2 GB de sistema, 4–8 GB de ARC conforme o perfil |
| `opnsense-lab` | 2 GB | fixo, sempre ligado |
| `haos` | 4 GB | fixo, sempre ligado |
| `monitoring` (LXC) | 1 GB | Prometheus e Grafana, sempre ligado — [ADR 0010](adr/0010-monitorizacao-fora-do-openshift.md) |
| `pbs` (LXC) | 2 GB | Proxmox Backup Server, sempre ligado — os vzdump correm de madrugada. Valor de partida, a medir |
| `ocp-sno` | 24 GB | sem balloon; o OpenShift lida mal com memória a desaparecer |
| `registry` (LXC) | 2 GB | registry OCI |
| `devbox` | 24 GB | balloon 16–24; inclui o compose de desenvolvimento (~13,5 GB de limites) — [ADR 0011](adr/0011-devbox-como-maquina-do-compose.md) |
| `bazzite` | 16 GB | hugepages, sem balloon |
| `runner` (LXC) | 2 GB | sob procura, fora dos perfis — [ADR 0012](adr/0012-runner-de-deploy-do-hobby.md) |
| **Total se tudo ligasse** | **83 GB** | **19 GB acima do físico** |

## Perfis

Cada perfil é um alvo do `Makefile` que arranca e pára conjuntos de guests. Não é uma sugestão —
é o mecanismo pelo qual o lab não entra em OOM.

| Perfil | RAM | Contém | Para quê |
|---|---:|---|---|
| `idle` | 15 GB | host, `opnsense-lab`, `haos`, `monitoring`, `pbs` | O estado por omissão. A casa funciona, a máquina é observada e salvaguardada, o lab dorme |
| `gaming` | 31 GB | `idle` + `bazzite` | Consola da sala |
| `dev` | 41 GB | `idle` + `devbox` + `registry` | O perfil de todos os dias: código e o compose de desenvolvimento |
| `platform` | 41 GB | `idle` + `ocp-sno` + `registry` | Exercícios de OpenShift e GitOps |
| `full-lab` | 65 GB | `idle` + `ocp-sno` + `registry` + `devbox` | Ciclo completo, só com os ajustes abaixo |

```bash
make profile-dev        # pára o que sobra, arranca o que falta
make profile-status     # mostra o que está ligado e quanta RAM está comprometida
```

Os perfis são idempotentes: correr `make profile-dev` duas vezes não faz nada na segunda.

O `runner` é o único guest fora dos perfis: mudar de perfil não o liga nem desliga. Liga-se à parte
quando há deploy e soma 2 GB a qualquer perfil:

```bash
make runner-start       # liga o runner (ADR 0012)
make runner-stop        # desliga-o
```

## O caso `full-lab`

Somado à letra, o `full-lab` dá 65 GB — 1 GB acima do tecto físico. Encostar ao tecto é pedir que
o `oom-killer` escolha por nós, e ele escolhe sempre mal.

Três ajustes, por esta ordem, põem o perfil em ~59 GB com 5 GB de margem:

1. **Baixar a ARC do ZFS de 8 para 4 GB.** É o ganho maior e o mais barato. Custo: menos cache de
   leitura, sensível no arranque de VMs, irrelevante depois.
   ```bash
   echo 4294967296 > /sys/module/zfs/parameters/zfs_arc_max   # runtime
   # persistente: /etc/modprobe.d/zfs.conf + update-initramfs -u
   ```
2. **Balloon do `devbox` em 16–24 GB.** A IDE remota e o compose cabem em 16 GB. Numa compilação
   `native-image`, o balloon devolve o que for preciso.
3. **Arrancar o `ocp-sno` primeiro.** É o guest que não tolera balloon e o que falha pior se não
   conseguir a memória de que precisa. Quem chega primeiro é servido.

O que **não** se faz: activar swap para os guests. Um cluster de Kubernetes a fazer swap é um cluster
que reporta saudável enquanto entrega latências absurdas — pior do que falhar às claras.

## O caso que deixou de ser impossível

`gaming` + `platform` = 57 GB. Até o compose de desenvolvimento passar para a `devbox`
([ADR 0011](adr/0011-devbox-como-maquina-do-compose.md)), pedia mais de 80 GB e não existia. Agora cabe
com 7 GB de margem: a `bazzite` fica com a GPU e o CCD 0, o OpenShift com o CCD 1.

Não vira perfil antes de ser medido no metal: o CPU dos dois em carga e a temperatura da caixa SFF
são as incógnitas, não a memória.

## CPU

O CPU não é o recurso escasso, mas o *pinning* também não é opcional — ver
[hardware.md](hardware.md#topologia-de-cpu).

| Guest | vCPU | CCD | Estratégia |
|---|---:|---|---|
| `bazzite` | 8 | 0 | `cpuset` fixo nos cores com V-Cache, sem partilha |
| `ocp-sno` | 12 | 1 | `cpuset` no CCD 1, sobrecomprometido com os restantes |
| `devbox` | 8 | 1 | idem; picos de `native-image` toleram contenção |
| `registry`, `haos`, `opnsense`, `monitoring`, `pbs`, `runner` | 12 no total | 1 | sem pinning, cargas leves |

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
| `registry`, `haos`, `opnsense`, `monitoring` | 140 GB |
| Snapshots e dumps locais | 200 GB |
| **Livre** | **~960 GB** |

Confortável hoje. A biblioteca de jogos é o que cresce sem aviso — é o primeiro sítio a olhar quando
a pool passar dos 80 %, porque o ZFS degrada em escrita a partir daí.

## Quando comprar mais

O upgrade que resolve o problema estrutural é **2 × 48 GB (96 GB)**. Não há terceiro slot: em AM5
Mini-ITX a única saída é trocar os módulos.

Contrapartida honesta: com dois módulos de dupla face, o controlador de memória do AM5 raramente
sustenta DDR5-6000 — espera-se cair para 5600 ou abaixo. Para este lab, capacidade vale mais do que
latência: 96 GB põem o `full-lab` confortável e tornam `gaming` + `platform` possível.

Fica em aberto e sem data. O lab funciona sem isso; o que não funcionaria era fingir que já cabe.
