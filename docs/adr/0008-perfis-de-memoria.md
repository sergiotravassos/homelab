# 0008 — Perfis de arranque em vez de tudo sempre ligado

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

A soma da memória pedida por todos os guests é 80 GB. A máquina tem 64 GB, em dois slots, os dois
ocupados. Ver [`capacity.md`](../capacity.md).

Não é um défice que se resolva com afinação: faltam 16 GB.

## Opções consideradas

| Opção | Notas |
|---|---|
| **Perfis de arranque** | Cada conjunto de guests é um alvo do `Makefile`; só sobe o que faz falta |
| **Ballooning agressivo em todos os guests** | O KVM reclama memória em cima da hora; o OpenShift e a VM de jogos reagem mal — o cluster reporta saudável e entrega latências absurdas |
| **Reduzir todos os guests até caberem** | 16 GB para o OpenShift é abaixo do mínimo praticável; a instalação falha ou o cluster não estabiliza |
| **Swap no host** | Faz caber no papel. Um Kubernetes a fazer swap é pior do que um Kubernetes desligado |
| **Comprar 96 GB já** | Resolve de facto; adia todo o lab e custa frequência de memória |
| **Segunda máquina** | Resolve tudo e duplica consumo, ruído e espaço |

## Decisão

**Perfis de arranque**, declarados no `Makefile` e idempotentes:

```
idle      12 GB   host + opnsense + haos          (por omissão, 24/7)
gaming    28 GB   idle + bazzite
dev       40 GB   idle + devbox + platform
platform  48 GB   idle + ocp-sno + platform
full-lab  64 GB   idle + ocp-sno + platform + devbox   (com ajustes)
```

`gaming` e `platform` não coexistem — pedem 80 GB. Aceite como limitação de desenho, documentada no
diagrama em vez de escondida.

O `full-lab` precisa de três ajustes para ter margem: ARC a 4 GB, balloon 8–16 no `devbox`, e
arrancar o `ocp-sno` primeiro.

## Consequências

**Positivas**

- O lab nunca chega a OOM. O limite é imposto antes de o `oom-killer` escolher por nós.
- Consumo eléctrico e ruído seguem o uso real: o estado por omissão são 12 GB e quase nenhuma carga.
- Obriga a declarar a memória de cada guest com intenção, em vez de a atribuir por hábito.
- Arrancar e parar guests com frequência expõe cedo quem não tolera reinícios — que é exactamente o
  tipo de defeito que interessa apanhar.

**Negativas**

- Nem tudo está disponível a qualquer momento. Mudar de contexto custa o tempo de arranque de um
  cluster.
- Testar integração entre a plataforma e o gaming é impossível. Na prática não faz falta: as duas
  cargas competem pela mesma pessoa, não só pela mesma máquina.
- Introduz estado implícito — "o que está ligado agora?". Mitigado por `make profile-status`.
- Serviços que dependam de estar sempre ligados não podem viver nos perfis não-`idle`. O Home
  Assistant está no `idle` exactamente por isso.
