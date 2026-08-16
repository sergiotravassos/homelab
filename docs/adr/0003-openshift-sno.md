# 0003 — OpenShift Single-Node em vez de k3s ou OKD

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

Trabalho todos os dias com microserviços Quarkus em OpenShift, entregues por Argo CD. O lab existe
para exercitar exactamente essa stack, incluindo a parte que não me compete no trabalho: instalar,
operar e reparar o cluster.

O constrangimento é a memória. Ver [`capacity.md`](../capacity.md).

## Opções consideradas

| Opção | RAM | A favor | Contra |
|---|---:|---|---|
| **OpenShift SNO** | ~24 GB | É o produto real: Operators, Routes, SCC, GitOps e Pipelines incluídos | Devorador de memória; instalação exigente em DNS |
| **OKD SNO** | ~24 GB | Mesma arquitectura, sem subscrição | Menos testado, menos documentado, ciclo de vida menos previsível |
| **k3s** | ~4 GB | Leve, arranca em segundos | Não é OpenShift. Faltam SCC, Routes, Operators e o catálogo — a parte que interessa aprender |
| **OpenShift Local (CRC)** | ~16 GB | Simples de pôr de pé | Explicitamente um ambiente de desenvolvimento; não se opera nem se avaria de forma realista |
| **Cluster de 3 nós** | 60 GB+ | Realismo de HA | Não cabe. Nem perto |

## Decisão

**OpenShift SNO**, instalado pelo instalador *agent-based*, com a subscrição de programador da Red
Hat. O OKD fica como alternativa registada, caso a subscrição se torne um problema.

A razão é directa: o objectivo não é ter Kubernetes a correr, é praticar OpenShift. Um k3s poupa
20 GB e retira do exercício quase tudo o que o torna útil — SCC, Routes, o modelo de Operators,
GitOps e Pipelines como produto.

Escolher o instalador *agent-based* em vez do *assisted installer* é deliberado: é totalmente
offline, a configuração cabe em dois ficheiros versionáveis, e força-me a perceber o Ignition em vez
de clicar num assistente.

## Consequências

**Positivas**

- O ambiente do lab espelha o do trabalho: mesmas APIs, mesmos operadores, mesmos modos de falha.
- GitOps e Pipelines vêm como operadores suportados, não como instalações avulsas.
- Praticar a instalação — DNS, Ignition, certificados — é metade da aprendizagem.

**Negativas**

- 24 GB de RAM, o que impede definitivamente correr o cluster em simultâneo com a VM de jogos.
- Sem HA. Não se pratica falha de nó de controlo, drenagem nem actualização com surge. É uma lacuna
  real e assumida.
- Exige subscrição de programador da Red Hat, renovável, e pull secret. Se isso mudar, migra-se para
  OKD e escreve-se novo ADR.
- Os registos DNS `api`, `api-int` e `*.apps` são pré-requisito rígido. É a causa mais comum de
  instalações falhadas e está no runbook antes de tudo o resto.
