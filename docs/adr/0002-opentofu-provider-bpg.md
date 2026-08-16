# 0002 — OpenTofu com o provider `bpg/proxmox`

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

Todos os guests têm de nascer de código. É a regra que dá forma ao repositório: uma máquina que não
possa ser destruída e recriada a partir do Git não conta.

Ficam por decidir duas coisas: que ferramenta de provisionamento, e que provider de Proxmox.

## Opções consideradas

### Ferramenta

| Opção | Notas |
|---|---|
| **OpenTofu** | Fork do Terraform sob a Linux Foundation, licença MPL. Compatível com os providers existentes |
| **Terraform** | Mesma linguagem, licença BUSL desde 2023 |
| **Pulumi** | Linguagens reais em vez de HCL; ecossistema Proxmox muito mais fino |
| **Só Ansible** | O módulo `community.general.proxmox` provisiona, mas sem plano nem grafo de dependências |

### Provider de Proxmox

| Opção | Notas |
|---|---|
| **`bpg/proxmox`** | Activo, cobre VM, LXC, ficheiros, utilizadores e ACL; suporte a `hostpci` e cloud-init |
| **`Telmate/proxmox`** | O mais antigo e o mais citado; manutenção irregular e cobertura de recursos mais fraca |

## Decisão

**OpenTofu com `bpg/proxmox`.**

O OpenTofu evita a incerteza de licenciamento do Terraform sem custo de migração — é a mesma
linguagem e os mesmos providers. Para um repositório público, a licença aberta importa.

O `bpg/proxmox` é o único provider com cobertura séria de `hostpci` (necessário para o passthrough da
GPU), de contentores LXC e de cloud-init. O `Telmate` sobrevive por inércia histórica.

**Ansible fica com o que lhe compete:** configuração dentro dos guests depois de existirem. Os dois
não se sobrepõem — OpenTofu cria, Ansible configura.

## Consequências

**Positivas**

- `tofu plan` mostra o desvio antes de ele custar caro. É a rede de segurança contra alterações
  feitas na interface web.
- O grafo de dependências trata da ordem de criação sem intervenção.
- Módulos (`proxmox-vm`, `proxmox-lxc`) evitam repetição entre seis guests.

**Negativas**

- O estado passa a ser um artefacto crítico. Fica num *backend* remoto compatível com S3 — nunca no
  disco do Mac, nunca neste repositório.
- O provider evolui depressa e introduz alterações incompatíveis entre versões menores. A versão é
  fixada com `~>` e as actualizações passam por PR.
- Recursos de nicho do Proxmox continuam a exigir Ansible ou intervenção manual. Aceitável: são
  poucos e estão documentados.

**Aplicação a partir do Mac, não do CI.** Não há runner dentro do lab e expor a API do Proxmox à
Internet para dar acesso a um runner do GitHub seria trocar segurança por conveniência. O CI valida;
o `apply` é local e deliberado. Se um dia houver runner self-hosted na VLAN de gestão, escreve-se
novo ADR.
