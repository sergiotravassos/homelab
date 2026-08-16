# Instalacao do OpenShift SNO

Instalador **agent-based**: totalmente offline, configuracao em dois ficheiros
versionaveis, e obriga a perceber o Ignition em vez de clicar num assistente.

Procedimento completo: [`../../docs/runbooks/02-install-openshift-sno.md`](../../docs/runbooks/02-install-openshift-sno.md).

## Ficheiros

| Ficheiro | O que e |
|---|---|
| `VERSION` | Versao alvo do cluster. Fixada de proposito |
| `install-config.yaml.example` | Topologia, rede e segredos do cluster |
| `agent-config.yaml.example` | Enderecos e interfaces do no |
| `work/` | Pasta de trabalho. **Ignorada pelo Git** |

> O `openshift-install` **consome** os dois ficheiros de configuracao ao gerar a
> ISO — apaga-os. Por isso e que se trabalha numa copia dentro de `work/` e os
> originais ficam como `*.example`.

## Antes de comecar

O DNS tem de resolver. Nao e opcional e o instalador nao avisa de forma util:

```
api.sno.lab.home.arpa       A   10.10.20.20
api-int.sno.lab.home.arpa   A   10.10.20.20
*.apps.sno.lab.home.arpa    A   10.10.20.20
```

## Segredos

O `pullSecret` e a `sshKey` **nao** estao aqui. Vem de fora:

```bash
# pull secret: https://console.redhat.com/openshift/install/pull-secret
export PULL_SECRET="$(cat ~/.config/openshift/pull-secret.json)"
export SSH_KEY="$(cat ~/.ssh/id_ed25519.pub)"

mkdir -p work
envsubst < install-config.yaml.example > work/install-config.yaml
cp agent-config.yaml.example work/agent-config.yaml
```
