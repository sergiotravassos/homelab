# Percurso de estudo

Este documento é um **mapa, não um tutorial**. Diz em que ordem aprender, o que ler antes de cada
etapa, e — a parte que importa — o que tens de conseguir explicar antes de avançar.

A regra é simples: **não avanças de etapa enquanto não conseguires responder às perguntas do portão
sem consultar nada.** Não é rigor por gosto. É que cada etapa assenta na anterior, e uma base mal
percebida só se manifesta três etapas depois, quando já não sabes onde procurar.

Não há prazos. Há ordem.

---

## Como usar isto

Cada etapa tem quatro partes:

| | |
|---|---|
| **Vais perceber** | Os conceitos. Se um nome te for estranho, é aqui que ele deixa de ser |
| **Ler** | Fontes oficiais. Evitei tutoriais de blogue: envelhecem e mentem por omissão |
| **Fazer** | Uma acção concreta, no repositório ou na máquina |
| **Portão** | Perguntas. Se não souberes responder, não passaste |

Os ficheiros do repositório têm um **cartão de leitura** no topo — o que faz, porque existe, o que
acontece se tirares — e cada um aponta para a etapa deste documento onde o conceito é explicado.

---

## O que podes estudar já, sem hardware

O teu Mac é Apple Silicon (ARM). Isso limita o que se pode praticar antes da máquina chegar, e vale
a pena saber o que é possível e o que não é.

| Queres praticar | Dá? | Como |
|---|---|---|
| Sintaxe de OpenTofu e Ansible | ✅ | `tofu validate` e `ansible-lint` não precisam de Proxmox nenhum — é o que este repo já corre no CI |
| Kubernetes e OpenShift | ✅ | OpenShift Local (CRC) tem versão para Apple Silicon. Não serve para operar um cluster a sério, serve para aprender `oc`, Routes, SCC, operadores |
| Contentores, Podman, Containerfile | ✅ | `podman machine` no Mac |
| Kafka, PostgreSQL, o padrão outbox | ✅ | Em contentores no Mac. É o que já fazes no trabalho — aqui é para praticar a falha |
| ZFS | ⚠️ | Só em leitura, ou num VPS Linux barato. No Mac não |
| Proxmox | ❌ | É x86_64. Em ARM só por emulação, tão lento que não ensina nada |
| Passthrough de GPU | ❌ | Precisa do metal |

**Recomendação:** etapa 0 (conceitos) e etapa 2 (OpenTofu) podem ser feitas inteiras a partir de
hoje. A etapa 6 (OpenShift) também, com CRC. As restantes esperam pela máquina.

---

## Etapa 0 — Fundamentos, antes de ligar nada

A conversa que devia ter vindo antes deste repositório existir.

### Vais perceber

**Virtualização.** O que é um hipervisor, e a diferença entre tipo 1 (corre directamente no
hardware — é o Proxmox) e tipo 2 (corre dentro de outro sistema — é o VirtualBox). Porque é que essa
diferença muda o desempenho e o acesso ao hardware.

**VM contra contentor.** Uma VM traz o seu próprio kernel; um contentor partilha o kernel do host.
Consequência prática, e é a que decide coisas neste lab: uma VM custa ~1 GB de RAM só em kernel e
sistema de ficheiros, um contentor LXC custa quase nada. Daí o Kafka e o PostgreSQL serem LXC e o
OpenShift ser VM.

**ZFS.** Não é só um sistema de ficheiros. Precisas de cinco palavras:
- *pool* — o conjunto de discos (aqui, `rpool`, com um disco só)
- *dataset* — como uma pasta, mas com propriedades próprias
- *zvol* — um disco virtual em bruto, é o que cada VM recebe
- *snapshot* — uma fotografia instantânea e barata, à qual podes voltar
- *ARC* — a cache em RAM. É a razão de existir metade do `docs/capacity.md`

E um conceito: *copy-on-write*. Escrever nunca sobrepõe o bloco antigo, escreve num novo. É o que
torna os snapshots gratuitos e o que causa a amplificação de escrita.

**Rede.** O que é uma *bridge* (um switch em software, dentro do host), o que é uma *etiqueta VLAN*
(um número no cabeçalho da trama que diz a que rede lógica pertence), e o que é uma porta *trunk*
(porta que transporta várias VLANs etiquetadas) contra uma porta *access* (uma VLAN só, sem
etiqueta).

**IOMMU.** O componente do CPU que traduz endereços de memória para dispositivos PCI. Sem ele não há
passthrough, porque uma VM não pode receber acesso directo a hardware sem uma forma de o isolar da
memória do resto do sistema.

### Ler

- [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html) —
  introdução, e os capítulos de *Qemu/KVM Virtual Machines* e *Linux Container (LXC)*. Salta a
  instalação e o cluster por agora.
- [OpenZFS — Basic Concepts](https://openzfs.github.io/openzfs-docs/) — pools, datasets, snapshots
- A tua própria `docs/hardware.md` e `docs/capacity.md` neste repo. Foram escritas para isto.

### Fazer

Nada de prático. Esta etapa é de leitura, e é a única que é.

### Portão

Consegues explicar, sem consultar:

1. Porque é que o Kafka deste lab corre em LXC e o OpenShift em VM?
2. O que é que a ARC do ZFS tem a ver com o OpenShift não arrancar?
3. Se tens uma NIC e queres seis redes isoladas, o que é preciso e onde?
4. O que é um snapshot ZFS e porque é que é barato?
5. Porque é que a `bazzite` não pode receber a GPU se o IOMMU estiver desligado na BIOS?

---

## Etapa 1 — Proxmox, à mão de propósito

### Vais perceber

Como o Proxmox representa as coisas: *node*, *VMID*, *storage*, *datastore*, `qm` para VMs, `pct`
para contentores, e o ficheiro de configuração de cada guest em `/etc/pve/qemu-server/<vmid>.conf`.

### Fazer

Segue o **[runbook 01](runbooks/01-bootstrap-proxmox.md)** até ao passo 3.

Depois — e isto é deliberado, contra a regra do repositório — **cria uma VM à mão na interface web.**
Uma Debian pequena, 1 vCPU, 1 GB. Instala-a, arranca-a, apaga-a.

Faz isto porque não podes automatizar o que não sabes fazer. Quando chegares ao OpenTofu, vais
reconhecer cada campo em vez de copiar HCL às cegas. Depois apagas essa VM e nunca mais crias uma na
interface.

Vê a configuração que a interface escreveu:

```bash
cat /etc/pve/qemu-server/999.conf
```

É esse ficheiro que o OpenTofu vai passar a gerar. Guarda esta imagem mental.

### Ler

- Proxmox Admin Guide, capítulo *Qemu/KVM* — as secções de CPU, memória e discos
- `man qm` no próprio host

### Portão

1. Qual é a diferença entre `qm` e `pct`, e porquê?
2. Onde está guardada a configuração de uma VM, e em que formato?
3. O que é `local-zfs` e como se relaciona com a `rpool`?
4. O que faz `qm shutdown` que `qm stop` não faz? Qual usarias num script?
5. Porque é que o `docs/adr/0001` escolheu Proxmox e não libvirt?

---

## Etapa 2 — OpenTofu

A etapa mais importante do repositório, e a que podes fazer inteira hoje.

### Vais perceber

**O que "infraestrutura como código" quer dizer na prática.** Descreves o estado desejado; a
ferramenta calcula a diferença face ao real e aplica só isso. Não escreves passos, escreves destino.

**Os cinco conceitos:**
- *provider* — o adaptador que fala com um sistema (aqui, a API do Proxmox)
- *resource* — uma coisa que existe (uma VM, um contentor)
- *variable* — entrada configurável
- *module* — um conjunto de recursos reutilizável, com entradas e saídas
- *state* — o ficheiro onde o OpenTofu guarda o que criou. **É o conceito mais perigoso:** se o
  perderes, a ferramenta deixa de saber que as tuas VMs são dela

**O ciclo:** `init` → `validate` → `plan` → `apply`. E porque é que ler o `plan` não é opcional.

**Drift.** O que acontece quando alguém muda uma coisa à mão e o código deixa de descrever a
realidade.

### Fazer

Sem Proxmox nenhum:

```bash
cd tofu/envs/lab
tofu init -backend=false
tofu validate
```

Depois lê, por esta ordem, e usa os cartões de leitura no topo de cada ficheiro:

1. `versions.tf` — o mais pequeno. Porque é que a versão do provider está fixada
2. `providers.tf` — como se autentica, e porque é que o token não está no ficheiro
3. `variables.tf` — todas as entradas do ambiente
4. `locals.tf` — o plano de endereçamento, e o interruptor `flat`/`vlan`
5. `haos.tf` — o guest mais simples
6. `../../modules/proxmox-vm/main.tf` — o motor. Este é o difícil; deixa-o para o fim
7. `bazzite.tf` — o mais complexo, porque tem passthrough

Exercício: no `haos.tf`, muda `memory_mb` de 4096 para 6144 e corre `tofu validate`. Depois desfaz.
Não podes correr `plan` sem Proxmox — mas vais poder, e o `plan` vai mostrar exactamente essa linha.

### Ler

- [OpenTofu — Core Concepts](https://opentofu.org/docs/language/) — providers, resources, variables,
  modules, state
- [bpg/proxmox no Terraform Registry](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
  — a documentação de `proxmox_virtual_environment_vm`. Compara com o que está no módulo
- `docs/adr/0002` deste repo — porque OpenTofu e não Terraform, e porque `bpg` e não `Telmate`

### Portão

1. O que acontece se apagares o ficheiro de state?
2. Porque é que o `apply` deste repositório corre do teu Mac e não do GitHub Actions?
3. O que é um módulo, e o que é que os módulos `proxmox-vm` e `proxmox-lxc` evitam?
4. No módulo há `ignore_changes = [started]`. O que é que isso resolve?
5. Se criares uma VM na interface web, o que é que o `tofu plan` vai dizer amanhã?
6. Porque é que `network_device` está escrito como lista e não como bloco?

---

## Etapa 3 — Ansible

### Vais perceber

Onde acaba o OpenTofu e começa o Ansible: **o OpenTofu cria as máquinas, o Ansible configura o que
está dentro delas.** Nunca se sobrepõem.

Os conceitos: *inventory* (que máquinas existem e como se agrupam), *playbook* (uma sequência de
estados desejados), *task*, *module*, *role* (um conjunto reutilizável de tasks), *handler* (algo que
corre só se outra coisa mudou), *facts* (o que o Ansible descobre da máquina).

E o conceito central: **idempotência.** Correr duas vezes tem de dar o mesmo resultado que correr
uma. Um playbook que só funciona na primeira execução é um script disfarçado.

### Fazer

```bash
make galaxy               # instala as colecções. Uma vez, e outra vez se falhar a resolver
cd ansible
ansible-lint .            # tem de passar no perfil production
```

> **Armadilha real, apanhada a escrever isto.** As colecções instalam em
> `ansible/collections`, que vem primeiro no `collections_path`. Se essa pasta
> ficar meia — uma instalação interrompida, um `rm` a meio — passa a **ofuscar**
> a cópia boa em `~/.ansible/collections`, e o `ansible-lint` diz que não
> encontra `community.general.timezone` sem explicar porquê. A cura é
> `rm -rf ansible/collections && make galaxy`.

Lê `roles/vfio/tasks/main.yml`. É o papel mais interessante do repo: verifica pré-condições antes de
mexer em nada, e não inventa valores que têm de ser apurados no metal.

Repara no `handlers/main.yml` — o `update-initramfs` corre **só** se um dos ficheiros mudou. É
idempotência em acção.

### Ler

- [Ansible — Getting Started](https://docs.ansible.com/ansible/latest/getting_started/index.html)
- [Ansible — Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/index.html) —
  sobretudo *handlers* e *conditionals*

### Portão

1. Qual é a fronteira entre o que faz o OpenTofu e o que faz o Ansible neste repo?
2. O que é idempotência, e como é que o papel `vfio` a consegue?
3. Porque é que o `ansible.cfg` obriga a correr tudo de dentro da pasta `ansible/`?
4. Porque é que o `haos` e a `bazzite` não estão no inventário?
5. O que é um handler e porque é que o `update-initramfs` é um?

---

## Etapa 4 — Rede e VLANs

### Vais perceber

802.1Q em detalhe: como uma etiqueta viaja na trama, o que é a *VLAN nativa* (PVID), e porque é que
uma bridge VLAN-aware faz o trabalho de um switch.

*Router-on-a-stick*: um router com uma interface física e uma sub-interface por VLAN, encaminhando
entre elas.

E a razão de existir tudo isto: **isolamento**. Uma lâmpada Zigbee comprometida chega à VLAN 30 e
para aí.

### Fazer

Compra o switch — é a única dependência de compra bloqueante do roadmap.

Antes disso, o lab corre em modo `flat`. Percebe o interruptor: `network_mode` em `locals.tf` e em
`group_vars/all.yml`. Vê o que muda quando passa de `flat` para `vlan`.

Depois: **desenha a matriz de fluxo em papel antes de a escrever em regras.** A tabela está em
`docs/network.md`. Confirma que consegues justificar cada ❌.

### Ler

- `docs/network.md` e `docs/adr/0005` deste repo
- [Proxmox — Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration) — a secção
  de VLANs
- Documentação do OPNsense sobre VLANs e Unbound

### Portão

1. O que é a VLAN nativa e porque é que este lab a deixa ser a LAN de casa?
2. Porque é que o OPNsense não é o router de casa?
3. Porque é que a VLAN 50 (`DEV`) tem rota para a 20 (`PLATFORM`) e a 30 (`IOT`) não tem para nada?
4. Porque é que o domínio é `lab.home.arpa` e não `lab.local`?
5. Se mudares o IP de gestão do Proxmox pela rede, o que acontece?

---

## Etapa 5 — Passthrough da GPU

A etapa com mais probabilidade de te fazer perder uma tarde. Vale a pena.

### Vais perceber

Como o `vfio-pci` rouba um dispositivo ao host antes de o kernel o reclamar. O que é um *grupo
IOMMU* e porque é que um dispositivo tem de estar sozinho no seu. Porque é que OVMF (UEFI) e `q35`
são requisitos.

E porque é que **o patch ACS está excluído** deste repo: desactiva um isolamento real em troca de
conveniência.

### Fazer

Segue `docs/gpu-passthrough.md` à risca. A ordem importa e há um ponto de paragem obrigatório: se
`lspci -nnk -d 1002:` não disser `vfio-pci`, **para**. Continuar não dá erro — dá um ecrã preto
mais tarde, sem pista nenhuma.

### Ler

- `docs/gpu-passthrough.md` e `docs/adr/0004`
- [Proxmox — PCI(e) Passthrough](https://pve.proxmox.com/wiki/PCI(e)_Passthrough)

### Portão

1. Porque é que o `Primary Video Adapter` da BIOS tem de ficar em `Integrated`?
2. O que é um grupo IOMMU e o que fazes se a GPU não estiver sozinha no seu?
3. Porque é que a `bazzite` tem `memory_floating_mb = 0`?
4. Passas o controlador USB inteiro em vez de portas. Porquê?
5. O que é o *reset bug* e como o testas antes de dar o passthrough por assente?

---

## Etapa 6 — OpenShift Single-Node

Podes começar hoje com o CRC, no Mac.

### Vais perceber

O que o OpenShift acrescenta ao Kubernetes: *Routes*, *SCC* (Security Context Constraints), o modelo
de *Operators* e o catálogo, *Projects* em vez de namespaces nus.

E a parte que não te compete no trabalho: instalar. RHCOS, *Ignition*, o instalador *agent-based*, e
porque é que **o DNS é a causa esmagadora de instalações falhadas**.

### Fazer

**Agora, no Mac:** instala o OpenShift Local (CRC) e passa uma tarde com `oc`. Cria um Project,
expõe uma Route, instala um operador do catálogo. Não é operar um cluster — é ganhar familiaridade
com a API.

**Quando tiveres a máquina:** o [runbook 02](runbooks/02-install-openshift-sno.md), e faz o passo 0
(DNS) com paciência antes de tudo o resto.

Depois **destrói o cluster e reinstala.** `make ocp-destroy && make ocp-install`. É o exercício mais
útil de todo o roadmap: a segunda instalação é onde percebes a primeira.

### Ler

- [OpenShift — Installing on a single node](https://docs.redhat.com/en/documentation/openshift_container_platform/)
- `docs/adr/0003` — porque SNO e não k3s
- `openshift/install/README.md`

### Portão

1. Que três registos DNS são obrigatórios e o que faz cada um?
2. O que é o Ignition e em que difere do cloud-init?
3. Porque é que a ISO do instalador expira em 24 horas?
4. Porque é que este cluster não é salvaguardado nos backups?
5. Qual é a lacuna real de um cluster de um nó só — o que é que não podes praticar?

---

## Etapa 7 — GitOps com Argo CD

### Vais perceber

A inversão: em vez de tu empurrares para o cluster, o cluster **puxa** do Git. O que é *reconciliação
contínua*, *self-heal*, *prune*.

O padrão *app-of-apps*: um único `Application` aplicado à mão que aponta para um directório cheio de
outros `Application`. E as *sync waves*, que resolvem "o CRD tem de existir antes do recurso".

### Fazer

`make gitops-bootstrap`, e depois observa:

```bash
oc get applications -n openshift-gitops -w
```

Depois **estraga alguma coisa à mão de propósito:**

```bash
oc scale deployment/<algo> --replicas=5 -n <namespace>
```

E vê o Argo CD desfazer-te o trabalho. É o self-heal, e é a razão de existir do padrão.

### Ler

- `openshift/gitops/README.md`
- [Argo CD — Core Concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)

### Portão

1. O que é o app-of-apps e quantas coisas aplicas à mão?
2. O que fazem as sync waves e o que se parte sem elas?
3. O que acontece a um `oc apply` manual num recurso gerido?
4. Como se faz rollback em GitOps?
5. Porque é que os segredos não podem estar em claro neste directório?

---

## Etapa 8 — Kafka, outbox e dados

Terreno teu, mas com um lado que o trabalho não te dá: **operar e avariar.**

### Vais perceber

Strimzi como operador, o modo KRaft (sem ZooKeeper), o que é um *rebalance* de consumidores visto de
dentro. E porque é que réplica 1 é honesto num nó só.

Debezium a ler o WAL do PostgreSQL, e porque é que **a aplicação nunca escreve directamente no
tópico** — é o que garante que não há evento sem escrita nem escrita sem evento.

### Fazer

A fase 7 do `docs/roadmap.md` é feita para aqui. Cada exercício produz um runbook novo:

- Mata o broker durante o consumo. Observa o rebalance
- Entrega a mesma mensagem duas vezes. Prova a idempotência
- Falha o failover do CloudNativePG. Cronometra a recuperação

### Ler

- [Strimzi documentation](https://strimzi.io/documentation/)
- [CloudNativePG documentation](https://cloudnative-pg.io/documentation/)

### Portão

1. Porque é que réplica 1 é aceitável aqui e inaceitável em produção?
2. Como é que o outbox garante atomicidade entre a escrita e o evento?
3. O que é um dead letter topic e quando é que uma mensagem lá vai?
4. Porque é que o `read-store` é descartável e o `orders-db` não?

---

## Etapa 9 — As peças avançadas

Deixadas para o fim de propósito. Nenhuma é necessária para o lab funcionar, e cada uma é um
conceito novo por si.

| Peça | O que aprendes | Quando |
|---|---|---|
| **`bootc` / imagens atómicas** | Sistemas imutáveis: a configuração vive na imagem, o rollback é um reboot | Quando a `devbox` te chatear com `rpm-ostree` |
| **SOPS + age** | Criptografia por valor, e como um repo público guarda segredos | Quando tiveres o primeiro segredo real |
| **Packer** | Construir imagens douradas em vez de instalar de cada vez | Quando clonar à mão te aborrecer |
| **Tekton** | CI dentro do cluster, com cache em PVC | Depois da etapa 7 |
| **Fedora Silverblue** | Porque um sistema read-only é diferente de tudo o que usaste | Ver nota abaixo |

> **Nota honesta sobre o `devbox`.** Escolhi Fedora Silverblue, que é imutável — não fazes
> `dnf install` como é normal. Isso é elegante e é um conceito a mais numa altura em que já tens
> muitos. A razão técnica de o `devbox` existir mantém-se e é sólida: **o teu Mac é ARM e o cluster
> é x86_64**, logo um binário nativo do GraalVM compilado no Mac não arranca no cluster.
>
> Mas o Silverblue é opcional. Se ele te travar, diz — troca-se por um Fedora Server normal em
> quinze minutos e o lab não perde nada de essencial.

---

## Prova de fogo

Quando conseguires fazer isto sem consultar nada, o lab cumpriu o seu objectivo:

- [ ] Explicar a arquitectura inteira a alguém, a partir dos diagramas, em quinze minutos
- [ ] Destruir e recriar qualquer guest a partir do repositório
- [ ] Restaurar o lab do zero num disco novo, cronometrado, seguindo o runbook 03
- [ ] Instalar o OpenShift SNO de memória, sabendo onde vai falhar
- [ ] Justificar cada ❌ da matriz de fluxo inter-VLAN
- [ ] Dizer, de cabeça, quanta RAM cada perfil compromete e porque é que dois não coexistem
- [ ] Defender cada um dos oito ADRs — incluindo o que se perde com cada decisão

O último é o que separa saber operar de saber decidir. É também o que se leva para uma entrevista.
