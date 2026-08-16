# Architecture Decision Records

Decisões com consequências, escritas quando ainda se sabe porquê.

O formato é curto de propósito: contexto, opções, decisão, e — a parte que costuma faltar — o que se
perde com ela. Um ADR que só lista vantagens não é um registo de decisão, é publicidade.

Uma decisão registada aqui não é imutável. Quando mudar, o ADR antigo passa a `Substituído por
NNNN` e escreve-se um novo. Não se reescreve o passado.

| # | Decisão | Estado |
|---|---|---|
| [0001](0001-hipervisor-proxmox-ve.md) | Proxmox VE como hipervisor | Aceite |
| [0002](0002-opentofu-provider-bpg.md) | OpenTofu com o provider `bpg/proxmox` | Aceite |
| [0003](0003-openshift-sno.md) | OpenShift Single-Node em vez de k3s ou OKD | Aceite |
| [0004](0004-passthrough-da-gpu.md) | iGPU para o host, dGPU inteira para o guest | Aceite |
| [0005](0005-vlans-com-switch-gerivel.md) | Segmentação 802.1Q, adoptada por fases | Aceite |
| [0006](0006-armazenamento-zfs-disco-unico.md) | ZFS num disco único, com backup a compensar | Aceite |
| [0007](0007-segredos-sops-age.md) | Segredos cifrados com SOPS + age, em repositório público | Aceite |
| [0008](0008-perfis-de-memoria.md) | Perfis de arranque em vez de tudo sempre ligado | Aceite |
