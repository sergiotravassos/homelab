# Roadmap

Projecto pessoal, sem prazos. A ordem é por dependência, não por data.

## Fase 0 — Metal

- [ ] Montar a máquina na Fractal Ridge
- [ ] `memtest86+` com EXPO activo, uma passagem completa
- [ ] Apurar a numeração dos CCDs e registá-la em `group_vars`
- [ ] Instalar o Proxmox VE, à mão, com ZFS na `rpool`
- [ ] `make bootstrap` — repositórios, IOMMU, `vfio-pci`, limite da ARC, token de API
- [ ] Confirmar `vfio-pci` ligado à GPU antes de criar qualquer VM
- [ ] Medir e registar o consumo em `idle`

## Fase 1 — Rede

- [ ] Comprar o switch gerível 2.5 GbE com 802.1Q
- [ ] Configurar o trunk e as portas de acesso
- [ ] Passar `network_mode` de `flat` para `vlan`
- [ ] Instalar o `opnsense-lab` e migrar DHCP e DNS do lab
- [ ] Escrever as regras inter-VLAN em `ansible/` e validar a matriz de fluxo
- [ ] Tailscale como subnet router para `10.10.0.0/16`

> Enquanto esta fase não estiver feita o lab corre em modo `flat`. Funciona; simplesmente não
> demonstra nada sobre segmentação.

## Fase 2 — Base de virtualização

- [ ] Template Fedora cloud com Packer
- [ ] Módulos `proxmox-vm` e `proxmox-lxc` validados no metal
- [ ] `haos` a correr, com o dongle Zigbee passado por USB
- [ ] LXC de plataforma: Kafka, PostgreSQL, registry
- [ ] Proxmox Backup Server e a primeira **restauração testada** — o backup só conta depois disso

## Fase 3 — Bancada

- [ ] Imagem `bootc` da `devbox` construída no GitHub Actions
- [ ] JetBrains Gateway a ligar de forma estável
- [ ] Toolchain completo: JDK 21, GraalVM, Quarkus CLI, Maven, Podman, `oc`, `tofu`
- [ ] Um `native-image` compilado de ponta a ponta, com o tempo registado

## Fase 4 — Consola

- [ ] Passthrough da GPU validado
- [ ] Imagem `bootc` derivada do Bazzite
- [ ] Controlador USB e Bluetooth passados
- [ ] Pinning no CCD 0 e hugepages, com medição antes e depois
- [ ] Sunshine para streaming dentro de casa

## Fase 5 — Plataforma

- [ ] Registos DNS do SNO no Unbound
- [ ] OpenShift SNO instalado pelo instalador *agent-based*
- [ ] OpenShift GitOps semeado com o app-of-apps
- [ ] Operadores: Strimzi, CloudNativePG, Kong Gateway, cert-manager, External Secrets
- [ ] LVM Storage Operator com uma StorageClass funcional
- [ ] Observabilidade: user-workload monitoring, Grafana Operator, OpenTelemetry, Tempo

## Fase 6 — A aplicação de demonstração

- [ ] `orders-api` com outbox transacional
- [ ] Debezium a publicar o outbox para o Kafka
- [ ] `inventory-worker` idempotente, com dead-letter topic
- [ ] `query-api` como projecção reconstruível
- [ ] Traço distribuído contínuo, atravessando o tópico
- [ ] Tekton a compilar imagem nativa dentro do cluster

## Fase 7 — Exercícios

A parte que justifica o lab existir. Cada um é para ser feito de propósito e escrito num runbook:

- [ ] Matar o broker de Kafka durante o consumo e observar o *rebalance*
- [ ] Entregar a mesma mensagem duas vezes e provar a idempotência
- [ ] Falhar o *failover* do CloudNativePG e cronometrar a recuperação
- [ ] Rollback de GitOps a partir de um estado partido
- [ ] Restaurar o cluster inteiro a partir de zero, só com o repositório
- [ ] Encher a `rpool` acima de 80 % e medir a degradação
- [ ] Deixar expirar um certificado de propósito e ver o que avisa

## Em aberto

| Assunto | Estado |
|---|---|
| 96 GB de RAM (2 × 48) | Adiado. Ver [capacity.md](capacity.md#quando-comprar-mais) |
| Segundo NVMe | Adiado. Backup primeiro, redundância depois |
| Runner self-hosted para `tofu apply` | Requer ADR; hoje o `apply` é local e deliberado |
| Inferência local de LLM na GPU | Conflito directo com a `bazzite`. Sem solução com um slot |
| Domínio real e ACME DNS-01 | Só quando houver algo que justifique certificados públicos |
| UPS | Provável antes do segundo disco: corte de energia é o modo de falha mais realista |

## Fora de âmbito

Ficam de fora por escolha, não por esquecimento:

- **Alta disponibilidade.** Um nó é um nó. Um cluster Proxmox de três nós ensinaria outra coisa;
  ensinaria-a com três vezes o consumo e o barulho.
- **Serviços expostos à Internet.** Nada é publicado. Acesso remoto é por Tailscale.
- **Media server, *arr stack, cloud pessoal.** São bons projectos e não são este. Este é sobre
  plataforma e operação.
- **Kubernetes vanilla a par do OpenShift.** O objectivo é aprofundar o OpenShift, não comparar
  distribuições.
