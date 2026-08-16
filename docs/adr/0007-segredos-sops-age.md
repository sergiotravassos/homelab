# 0007 — Segredos cifrados com SOPS + age, em repositório público

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

O repositório é público, deliberadamente — parte do valor é poder mostrá-lo. Ao mesmo tempo, a
infraestrutura precisa de tokens da API do Proxmox, chaves SSH, credenciais de base de dados, pull
secret da Red Hat e certificados.

Um único segredo em claro num repositório público é comprometido em minutos por *scrapers*
automáticos. Não é hipótese, é certeza.

## Opções consideradas

| Opção | Notas |
|---|---|
| **SOPS + age** | Cifra por valor no próprio ficheiro; o diff continua legível; chaves modernas e simples |
| **SOPS + GPG** | Igualmente capaz; gestão de chaves GPG é desnecessariamente dolorosa |
| **git-crypt** | Transparente; cifra o ficheiro inteiro, o que torna os diffs opacos |
| **Vault / OpenBao** | A resposta certa à escala de uma empresa; um serviço a mais para manter e que tem de estar de pé antes de tudo o resto |
| **Repositório privado com segredos em claro** | Resolve o scraping e não resolve nada mais; e o repositório deixa de ser mostrável |
| **Tudo fora do Git, em `.env` locais** | Simples; e a infraestrutura deixa de ser reprodutível |

## Decisão

**SOPS com chaves age.** Regras de cifra em `.sops.yaml`; a chave privada vive em
`~/.config/sops/age/keys.txt` e **nunca** entra em Git.

Dentro do cluster, o External Secrets Operator injecta os valores. Os ficheiros `*.example` mostram
a forma, nunca o conteúdo.

Defesa em profundidade, porque uma camada só falha:

1. `.sops.yaml` define o que é cifrado, por caminho — não depende de eu me lembrar.
2. `gitleaks` corre no `pre-commit` e outra vez no CI, e falha o build.
3. `.gitignore` exclui os padrões conhecidos (`*.tfvars`, `*.key`, `kubeconfig`, `auth/`).
4. O token da API do Proxmox nem sequer é cifrado no repositório: vem do Keychain do macOS em tempo
   de execução.

## Consequências

**Positivas**

- O repositório pode ser público sem ressalvas.
- Cifra por valor mantém o `git diff` útil: vê-se que uma chave mudou sem ver o seu conteúdo.
- Um só ficheiro (`keys.txt`) para guardar em segurança. Recuperação é trivial.
- Sem serviço adicional a manter — o que importa num lab que se desliga.

**Negativas**

- **Perder a chave `age` significa perder todos os segredos cifrados.** Cópia offline obrigatória,
  fora desta máquina. É a peça mais crítica do lab inteiro e não tem redundância automática.
- Rotação é manual. Sem TTL, sem renovação automática, sem auditoria de acesso — tudo o que um Vault
  daria.
- O ficheiro cifrado fica no histórico para sempre. Se um segredo escapar, o procedimento é **rodar
  o segredo**, não reescrever o histórico: assumir que já foi visto é a única postura segura.
- SOPS tem de estar instalado em qualquer sítio de onde se aplique infraestrutura. Fixado no
  `.mise.toml`.
