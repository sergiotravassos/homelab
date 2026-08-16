# Runbook 02 — Instalar o OpenShift Single-Node

**Frequência:** por instalação de cluster. Reinstalar é normal e não é derrota.
**Duração:** ~70 minutos, quase tudo à espera.
**Requer:** DNS a funcionar, 24 GB livres, pull secret da Red Hat.

Decisão e alternativas: [`../adr/0003-openshift-sno.md`](../adr/0003-openshift-sno.md).

---

## 0. DNS primeiro. Sempre.

A causa esmagadoramente mais comum de instalações falhadas é DNS. Não é opcional, não é
"resolve-se depois", e o instalador não avisa de forma útil.

No Unbound do OPNsense (ou no `dnsmasq` da fase 1):

| Registo | Tipo | Valor |
|---|---|---|
| `api.sno.lab.home.arpa` | A | `10.10.20.20` |
| `api-int.sno.lab.home.arpa` | A | `10.10.20.20` |
| `*.apps.sno.lab.home.arpa` | A | `10.10.20.20` |

Confirmar do Mac **antes de continuar**:

```bash
for n in api api-int random.apps; do
  dig +short "$n.sno.lab.home.arpa" | grep -q 10.10.20.20 \
    && echo "ok   $n" || echo "FALHA $n"
done
```

Se algum falhar, parar. Instalar sem DNS é perder uma hora para chegar a um erro obscuro.

---

## 1. Preparar

```bash
mise install                       # openshift-install e oc, versões fixadas
mkdir -p openshift/install/work && cd openshift/install/work
```

Descarregar o pull secret de <https://console.redhat.com/openshift/install/pull-secret> e guardá-lo
**fora do repositório**:

```bash
# nunca em Git — o .gitignore já exclui, mas a regra é não confiar só nisso
mv ~/Downloads/pull-secret.txt ~/.config/openshift/pull-secret.json
```

Preencher a partir dos exemplos versionados:

```bash
cp ../install-config.yaml.example install-config.yaml
cp ../agent-config.yaml.example agent-config.yaml
```

Em `install-config.yaml`: `baseDomain: lab.home.arpa`, `metadata.name: sno`, o `pullSecret` e a
`sshKey`.
Em `agent-config.yaml`: o endereço MAC da interface da VM e `10.10.20.20/24`.

> O `openshift-install` **consome** estes ficheiros — apaga-os ao gerar a ISO. Por isso é que se
> trabalha numa pasta `work/` e os originais ficam como `*.example`.

---

## 2. Gerar a ISO

```bash
openshift-install --dir . agent create image
```

Produz `agent.x86_64.iso`. Enviar para o Proxmox:

```bash
scp agent.x86_64.iso root@10.10.10.10:/var/lib/vz/template/iso/
```

---

## 3. Criar a VM

```bash
cd ../../../ && make apply     # tofu cria ocp-sno com a ISO já anexada
```

Especificação em `tofu/envs/lab/ocp-sno.tf`: 12 vCPU no CCD 1, 24 GB sem balloon, 200 GB, VLAN 20,
MAC fixo — o mesmo que está no `agent-config.yaml`.

Arrancar a VM. O arranque é a partir da ISO; a partir daí é automático.

---

## 4. Esperar

```bash
openshift-install --dir openshift/install/work agent wait-for bootstrap-complete
openshift-install --dir openshift/install/work agent wait-for install-complete
```

Ritmo normal: ~15 min até `bootstrap-complete`, ~50 min até `install-complete`. A VM reinicia
sozinha algumas vezes — é esperado e não é sinal de erro.

Para acompanhar de perto:

```bash
ssh core@10.10.20.20 'journalctl -b -f -u release-image.service -u bootkube.service'
```

---

## 5. Primeiro acesso

O instalador imprime a palavra-passe de `kubeadmin` e escreve o `kubeconfig`:

```bash
export KUBECONFIG=openshift/install/work/auth/kubeconfig
oc get clusteroperators          # todos AVAILABLE=True, DEGRADED=False
oc get nodes                     # um nó, Ready, com os papéis master e worker
```

Consola web: `https://console-openshift-console.apps.sno.lab.home.arpa`.

```bash
cp openshift/install/work/auth/kubeconfig ~/.kube/config-sno
# a pasta auth/ está no .gitignore; confirmar antes de qualquer commit
```

---

## 6. Semear o GitOps

A partir daqui o cluster gere-se a si próprio.

```bash
make gitops-bootstrap
```

Instala o operador OpenShift GitOps e aplica um único `Application` — o app-of-apps em
[`openshift/gitops/bootstrap/`](../../openshift/gitops/bootstrap/). O Argo CD trata do resto:
Strimzi, CloudNativePG, Kong, cert-manager, External Secrets, observabilidade.

```bash
oc get applications -n openshift-gitops -w
```

---

## 7. Pós-instalação

- [ ] Trocar o `kubeadmin` por um IdP (htpasswd chega para um lab) e **remover o `kubeadmin`**
- [ ] LVM Storage Operator, com a `StorageClass` marcada como predefinida
- [ ] User-workload monitoring activo
- [ ] Certificados de `*.apps` emitidos pelo cert-manager
- [ ] Guardar o `kubeconfig` num sítio seguro — cifrado, fora do repositório

---

## Problemas conhecidos

| Sintoma | Causa | Solução |
|---|---|---|
| Para em `Waiting for bootstrap` | DNS | Repetir o passo 0. É quase sempre isto |
| `x509: certificate has expired` | ISO com mais de 24 h | Regenerar a ISO. Os certificados de bootstrap são de curta duração |
| Operadores em `Degraded` por armazenamento | Sem `StorageClass` predefinida | Instalar o LVM Storage Operator e marcá-la como default |
| Instalação falha por memória | Menos de 24 GB disponíveis | `make profile-status`; parar `bazzite` e `devbox` |
| `oc` responde muito devagar | Cluster ainda a assentar | Esperar mais 10 min antes de diagnosticar |
| Nó `NotReady` após reinício | Serviços a arrancar por ordem | Esperar; se persistir, `journalctl -u kubelet` |

## Recomeçar do zero

Não custa nada e é o exercício mais útil deste runbook:

```bash
make ocp-destroy && rm -rf openshift/install/work && make ocp-install
```
