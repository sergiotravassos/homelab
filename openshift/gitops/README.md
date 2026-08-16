# GitOps

Um unico `Application` e aplicado a mao — o app-of-apps. Tudo o resto e o Argo CD
a ler este directorio.

```
bootstrap/    o minimo aplicado com 'oc apply': operador + app-of-apps
platform/     operadores e servicos partilhados
apps/         as aplicacoes de demonstracao
```

## Semear

```bash
make gitops-bootstrap
```

## A regra

Depois disto, **nada chega ao cluster por `oc apply`**. O `selfHeal` esta ligado:
uma alteracao a mao e revertida no ciclo seguinte. E essa a intencao — torna o
desvio impossivel de ignorar em vez de silencioso.

Para mudar alguma coisa: PR neste repositorio.

## Ordem de sincronizacao

Sync waves, porque a ordem importa:

| Wave | O que |
|---:|---|
| -1 | Namespaces e operadores (Strimzi, CloudNativePG, Kong, cert-manager, ESO) |
| 0 | Instancias geridas por esses operadores: cluster Kafka, cluster PostgreSQL |
| 1 | Observabilidade |
| 2 | Aplicacoes |

Sem waves, o Argo CD tenta criar um `Kafka` antes de o CRD existir e falha o
primeiro sync de cada vez que o cluster e reconstruido.

## Segredos

Cifrados com SOPS + age (ver [`../../docs/adr/0007-segredos-sops-age.md`](../../docs/adr/0007-segredos-sops-age.md)),
injectados no cluster pelo External Secrets Operator. Nenhum `Secret` em claro
neste directorio — o repositorio e publico.
