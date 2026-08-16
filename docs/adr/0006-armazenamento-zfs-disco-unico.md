# 0006 — ZFS num disco único, com backup a compensar

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

Há um NVMe de 2 TB e um segundo slot M.2 livre. A motherboard é Mini-ITX: não há espaço para uma
matriz de discos, e o orçamento já está gasto.

O lab corre a automação da casa (Home Assistant), o que eleva o custo de perder dados de "chatice de
laboratório" para "as luzes deixam de funcionar".

## Opções consideradas

| Opção | A favor | Contra |
|---|---|---|
| **ZFS num disco** | Checksums, snapshots baratos, `zfs send` para backup, compressão transparente | Sem redundância; consome RAM na ARC; amplificação de escrita |
| **LVM-thin** | Leve, menos escrita, é o que o Proxmox usa por omissão | Sem checksums, sem detecção de corrupção silenciosa, snapshots mais frágeis |
| **ext4 simples** | Máxima simplicidade | Sem snapshots, o que torna qualquer actualização um risco sem retorno |
| **Comprar já o segundo NVMe e fazer espelho** | Redundância real | Adia todo o lab por causa de uma compra; e redundância não substitui backup |

## Decisão

**ZFS numa pool única (`rpool`)**, com `ashift=12`, `compression=zstd`, `atime=off` e ARC limitada
explicitamente.

A redundância fica adiada. O **backup não fica**: o Proxmox Backup Server e uma restauração testada
são requisito da Fase 2 do roadmap, antes de qualquer serviço a sério assentar aqui.

A ordem é deliberada — redundância protege de falha de disco, backup protege de tudo o resto,
incluindo do erro mais provável neste lab, que sou eu.

## Consequências

**Positivas**

- Snapshot antes de cada actualização, com retorno em segundos. Transforma actualizações arriscadas
  em operações reversíveis.
- Checksums detectam corrupção silenciosa em vez de a propagarem para os backups.
- `zfs send` incremental torna o backup barato.
- `zstd` dá compressão útil sem custo mensurável de CPU num 9950X3D.

**Negativas**

- **Um disco é um ponto único de falha.** Assumido, mitigado por backup, não resolvido.
- A ARC compete com os guests pela memória — o recurso escasso. Limitada a 8 GB, ou 4 GB no perfil
  `full-lab`. Ver [`capacity.md`](../capacity.md).
- Amplificação de escrita reduz a vida do SSD. O 990 PRO tem 1 200 TBW; com `atime=off` e
  `volblocksize` de 16 K nos zvols, o desgaste esperado de um lab fica dentro da garantia. A ser
  monitorizado por SMART, não presumido.
- O `rpool` acima de 80 % degrada em escrita. É uma verificação de rotina, não um alarme surpresa.
