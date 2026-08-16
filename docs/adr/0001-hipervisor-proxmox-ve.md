# 0001 — Proxmox VE como hipervisor

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

O lab precisa de correr, na mesma máquina, cargas com requisitos incompatíveis: um cluster de
Kubernetes, uma appliance fechada (Home Assistant OS), uma VM de jogos com passthrough de GPU e
alguns serviços de dados leves. Isto exige virtualização completa com passthrough PCI, e não apenas
contentores.

A máquina é uma só e não haverá segunda. Seja o que for que for escolhido, é a camada que nunca pode
ser recriada por código — é a fundação a partir da qual tudo o resto nasce.

## Opções consideradas

| Opção | A favor | Contra |
|---|---|---|
| **Proxmox VE** | KVM e LXC na mesma interface; ZFS integrado; API REST madura com bom suporte em IaC; passthrough documentado | Interface web convida a alterações manuais que fogem ao código |
| **Fedora/RHEL + libvirt** | Mais próximo do que uso profissionalmente; sem camada extra | Sem LXC integrado, sem gestão de backup, muito mais para montar à mão |
| **XCP-ng** | Hipervisor tipo 1 sólido, boa gestão de pools | Ecossistema de IaC mais fraco; ZFS não é cidadão de primeira |
| **ESXi** | Padrão da indústria | Licenciamento hostil a laboratórios desde 2024 |
| **Kubernetes com KubeVirt** | Tudo numa API | Complexidade absurda para um nó; passthrough de GPU muito mais frágil |

## Decisão

**Proxmox VE.** Pesou sobretudo a combinação de três coisas que mais nenhuma opção junta: KVM com
passthrough bem documentado, LXC para os serviços leves onde uma VM inteira seria desperdício de
memória — o recurso escasso deste lab — e uma API que o OpenTofu sabe conduzir.

O ZFS integrado resolve snapshots e backup sem software adicional.

## Consequências

**Positivas**

- Guests pesados em KVM e serviços leves em LXC, com a mesma ferramenta e o mesmo backup.
- `vzdump` e Proxmox Backup Server resolvem a estratégia de cópias sem projecto próprio.
- A comunidade de homelab documenta exaustivamente o passthrough de GPU nesta plataforma.

**Negativas**

- A instalação do hipervisor é manual e fica fora do código. Está assumido e documentado em
  [`runbooks/01-bootstrap-proxmox.md`](../runbooks/01-bootstrap-proxmox.md).
- A interface web torna trivial criar uma VM à mão — e uma VM criada à mão é uma VM que ninguém
  consegue recriar. Mitigação: a UI serve para observar; `tofu plan` corre com regularidade e
  denuncia o desvio.
- O Proxmox assenta em Debian, não em RHEL. É a única peça do lab fora do ecossistema Red Hat, o que
  afasta ligeiramente o exercício do meu ambiente profissional.
