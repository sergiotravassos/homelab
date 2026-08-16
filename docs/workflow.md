# Fluxo de trabalho

Ver o desenho: **[diagrams/05-workflow.svg](diagrams/05-workflow.svg)**.

O MacBook é um terminal. Não hospeda serviços, não compila nada pesado e não guarda estado que não
esteja em Git ou num gestor de segredos. Perder o portátil custa um `git clone` e restaurar duas
chaves — a de SSH e a `age` dos segredos.

Isto não é minimalismo por gosto. É a única forma de o lab ser reprodutível: se o portátil for
necessário para a infraestrutura funcionar, a infraestrutura não está em código.

## O que corre onde

| | MacBook | `devbox` | `ocp-sno` | GitHub |
|---|---|---|---|---|
| Editar código | ✅ IDE | — | — | — |
| Compilar | ❌ | ✅ | ✅ Tekton | ✅ Actions (fallback) |
| Correr testes | ❌ | ✅ | ✅ | ✅ |
| Guardar estado | ❌ | ❌ | ✅ | ✅ fonte de verdade |
| `tofu apply` | ✅ | ✅ | — | ❌ nunca |
| `oc apply` a workloads | ❌ | ❌ | via Argo CD | — |

Duas linhas merecem explicação:

**`tofu apply` corre do Mac, não do CI.** Não há *runner* dentro do lab, e dar a um runner do GitHub
acesso à API do Proxmox implicaria expor essa API. O CI valida; a aplicação é local e deliberada.
Quando existir um runner *self-hosted* na VLAN de gestão, isto muda — e passará por um ADR.

**Nada chega ao cluster por `oc apply`.** O Argo CD tem `selfHeal` ligado. Uma alteração à mão é
revertida no ciclo seguinte, e é essa a intenção: torna o desvio impossível de ignorar em vez de
silencioso.

## Ambiente no Mac

Toda a ferramenta é gerida por [`mise`](https://mise.jdx.dev/), com versões fixadas em `.mise.toml`.
Sem `brew install` avulso, sem versões diferentes entre a minha máquina e o CI.

```bash
brew install mise direnv
mise install          # instala tudo o que .mise.toml declara
direnv allow          # carrega o ambiente ao entrar na pasta
```

O `.envrc` exporta o endereço do Proxmox e o caminho da chave `age`. O token da API **não** está lá
— vem do Keychain do macOS:

```bash
security add-generic-password -a "$USER" -s homelab-proxmox-token -w
```

## Ciclo de infraestrutura

```
editar → PR → Actions valida → merge → make plan → make apply → make configure
```

1. **Editar.** Alterações em `tofu/`, `ansible/` ou `openshift/`.
2. **PR.** Mesmo a trabalhar sozinho. O PR é onde o `tofu plan` fica registado e onde daqui a seis
   meses se percebe porque é que uma máquina tem 16 GB e não 12.
3. **Actions.** `tofu fmt -check`, `tofu validate`, `tflint`, `trivy config`, `ansible-lint`,
   `yamllint`, `gitleaks`. Não faz deploy.
4. **`make plan`.** Ler o plano. Um plano que não se percebe não se aplica.
5. **`make apply`.** OpenTofu contra a API do Proxmox.
6. **`make configure`.** Ansible por SSH; é aqui que os guests deixam de ser genéricos.

O estado do OpenTofu vive num *backend* remoto compatível com S3, não no disco do Mac e não neste
repositório. Configuração em `tofu/envs/lab/backend.tf.example`.

## Ciclo de aplicação

O desenvolvimento acontece na `devbox`, não no Mac. O JetBrains Gateway abre a IDE contra a VM e o
portátil fica a ser ecrã e teclado.

```bash
ssh devbox                  # ~/.ssh/config aponta para 10.10.50.50
# ou: JetBrains Gateway → New Connection → SSH → devbox
```

Porquê: um build `native-image` de GraalVM quer 8 núcleos e 16 GB e demora minutos. Fazê-lo num
portátil a bateria, com o mesmo JDK e as mesmas versões do cluster, é lutar contra a máquina errada.
Na `devbox` o toolchain está numa imagem `bootc` versionada e é idêntico para toda a gente — mesmo
que "toda a gente" seja uma pessoa.

```
código na devbox → push → build (Tekton ou Actions) → imagem assinada no registry
   → bump do digest no repo de gitops → Argo CD sincroniza → OpenShift
```

O único elo entre os dois ciclos é o **digest da imagem**. Nunca `:latest`: uma tag móvel torna
impossível responder à pergunta "o que é que estava a correr às 3 da manhã".

## Segredos

O repositório é público. A regra é absoluta: nada em claro.

```bash
age-keygen -o ~/.config/sops/age/keys.txt     # uma vez; a chave nunca entra em Git
sops -e -i openshift/gitops/apps/valores-secretos.yaml
sops openshift/gitops/apps/valores-secretos.yaml   # abre desencriptado no $EDITOR
```

O `.sops.yaml` define que caminhos são cifrados e com que chave. O `gitleaks` corre em cada PR e no
`pre-commit`. Ficheiros `*.example` mostram a forma; nunca o conteúdo.

Se um segredo escapar para o histórico, o procedimento é rodar o segredo — não reescrever o
histórico. Assumir que já foi visto é a única postura segura.

## Convenções de Git

- `main` protegida, merge por PR, histórico linear.
- Commits em português, no imperativo: `adiciona módulo proxmox-vm`, `corrige cpuset do CCD 0`.
- Um PR por decisão. Se o PR precisa de um ADR, o ADR vai no mesmo PR.

## Rotina de operação

| Quando | O quê |
|---|---|
| Ao começar | `make profile-status`, depois o perfil que fizer falta |
| Ao acabar | `make profile-idle` — a máquina volta aos 12 GB |
| Semanal | `make backup-verify` — um backup por testar não é um backup |
| Mensal | `make update` — Proxmox, imagens `bootc`, operadores; sempre por PR |
| Quando algo parte | [`runbooks/`](runbooks/) primeiro; se não houver runbook, escreve-se um a seguir |
