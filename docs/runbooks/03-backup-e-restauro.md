# Runbook 03 — Backup e restauro

**Frequência:** backup automático diário; verificação semanal; restauro completo trimestral.

Há um disco. Ver [`../adr/0006-armazenamento-zfs-disco-unico.md`](../adr/0006-armazenamento-zfs-disco-unico.md).
O backup não é boa prática neste lab — é o que substitui a redundância que não existe.

> **Um backup por restaurar não é um backup.** É um ficheiro grande que dá uma sensação agradável.
> A parte deste runbook que interessa é a secção 4.

---

## O que é preciso salvar

| Dado | Onde vive | Como se recupera | Criticidade |
|---|---|---|---|
| Configuração da infraestrutura | Este repositório, GitHub | `git clone` | Baixa — está replicado |
| **Chave `age` dos segredos** | `~/.config/sops/age/keys.txt` | **Cópia offline manual** | **Máxima — sem ela, nada se decifra** |
| Estado do OpenTofu | Backend remoto S3-compat | Versionamento do bucket | Alta |
| Base de dados do Home Assistant | VM `haos` | Backup do PBS + backup nativo do HA | Alta — histórico não se recria |
| Volumes do PostgreSQL | LXC `postgres` e PVC no cluster | PBS + `pg_dump` lógico | Média |
| Tópicos de Kafka | LXC `kafka` | Não se salva | Nenhuma — reconstrutíveis |
| Biblioteca Steam | VM `bazzite` | Não se salva | Nenhuma — 250 GB que se voltam a descarregar |
| `kubeconfig`, credenciais do cluster | `~/.kube/` | Reinstalar o cluster | Baixa — o cluster é descartável |

A coluna que mais importa é a última. Salvar tudo é caro e treina o instinto errado; a pergunta é
sempre "o que é que não consigo recriar?".

**A chave `age` é o único item sem redundância automática.** Cópia offline, fora desta máquina,
feita à mão. Perdê-la significa perder todos os segredos cifrados do repositório, para sempre.

---

## 1. Proxmox Backup Server

O PBS corre como LXC em `10.10.10.11`, com o *datastore* num disco externo — não na `rpool`. Um
backup no mesmo disco que os dados protege de erro humano e de nada mais.

```bash
make pbs-deploy
```

Retenção: `keep-daily=7 keep-weekly=4 keep-monthly=6`. A desduplicação do PBS torna isto barato.

## 2. Backup automático

`vzdump` nocturno, configurado pelo Ansible:

| Guest | Modo | Horário | Retenção |
|---|---|---|---|
| `haos` | snapshot | diário 03:00 | 7 / 4 / 6 |
| `opnsense-lab` | snapshot | diário 03:15 | 7 / 4 / 6 |
| `platform` (LXC) | snapshot | diário 03:30 | 7 / 4 / 2 |
| `devbox` | snapshot | semanal, domingo | 4 |
| `ocp-sno` | — | não é salvaguardado | reinstalável em ~1 h |
| `bazzite` | — | não é salvaguardado | reinstalável, dados na cloud da Steam |

Snapshots ZFS complementam, para retorno imediato:

```bash
zfs list -t snapshot -o name,used,creation -s creation | tail
```

## 3. Verificação semanal

```bash
make backup-verify
```

Corre `proxmox-backup-client` em modo de verificação sobre os snapshots recentes, confirma que a
tarefa nocturna correu nas últimas 24 h e que o *datastore* tem espaço. Falha ruidosamente — um
backup silenciosamente parado é o pior modo de falha possível.

## 4. Restauro — o exercício trimestral

Marcar no calendário. É a única forma de saber que o backup existe.

### 4.1 Restaurar um guest

```bash
ssh root@10.10.10.10 'proxmox-backup-client list --repository pbs@pbs@10.10.10.11:homelab'
qmrestore <ficheiro> <novo-vmid> --storage rpool
```

Restaurar sempre para um **VMID novo**, com a rede desligada, e comparar antes de trocar. Restaurar
por cima do original transforma um teste numa avaria.

### 4.2 Restaurar o lab inteiro

O cenário real: o NVMe morre. Sequência, com o tempo que demora de verdade:

| # | Passo | Tempo |
|---|---|---|
| 1 | Substituir o disco | — |
| 2 | [Runbook 01](01-bootstrap-proxmox.md), passos 1 a 3 | 60 min |
| 3 | Recuperar a chave `age` da cópia offline | 5 min |
| 4 | `git clone` do repositório | 1 min |
| 5 | `make bootstrap && make configure-host` | 20 min |
| 6 | Restaurar `haos` e `opnsense-lab` do PBS | 20 min |
| 7 | `make apply` — os restantes guests nascem de novo | 30 min |
| 8 | `make ocp-install` | 70 min |
| 9 | `make gitops-bootstrap` | 15 min |

**Total: ~3h30 até o lab estar completo; ~2h até a casa voltar ao normal.** Os passos 6 e 7 são a
diferença entre o que foi salvo e o que é recriado — e o objectivo permanente do repositório é
empurrar o máximo possível de trabalho para o passo 7.

Se este exercício demorar muito mais do que o previsto, o problema não é o backup: é que alguma
coisa deixou de estar em código. Corrigir aí.

---

## Cenários de falha

| Cenário | Impacto | Recuperação |
|---|---|---|
| Falha do NVMe | Total | Sequência 4.2 — ~3h30 |
| Corrupção de um guest | Um serviço | Snapshot ZFS ou restauro do PBS — minutos |
| Actualização má do Proxmox | Host | `proxmox-boot-tool` para o kernel anterior |
| Cluster OpenShift partido | Plataforma | Reinstalar. É descartável por desenho |
| **Chave `age` perdida** | **Todos os segredos** | **Sem recuperação.** Rodar tudo à mão |
| Corte de energia | Nenhum, se o `zpool` aguentar | `Restore on AC Power Loss = Power On`. Uma UPS está no roadmap |
| Erro humano em `tofu apply` | Variável | `git revert` e reaplicar |

O `.gitignore` e o `gitleaks` existem para que a linha a negrito nunca seja acompanhada de "e os
segredos também estavam no GitHub".
