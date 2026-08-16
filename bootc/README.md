# Imagens bootc

Duas VMs deste lab correm sistemas atomicos, imutaveis: a `bazzite` e a `devbox`.
Em sistemas assim a configuracao **vive na imagem**, nao em tarefas de
configuracao aplicadas depois. Isso muda o modelo:

| Sistema tradicional | Sistema bootc |
|---|---|
| Instalar, depois configurar com Ansible | Construir a imagem, depois arrancar |
| Estado diverge com o tempo | Estado e o que a imagem diz |
| Rollback = restaurar backup | Rollback = arrancar no deployment anterior |
| Configuracao em `roles/` | Configuracao no `Containerfile` |

As imagens sao construidas pelo GitHub Actions e publicadas em `ghcr.io`. A VM
adopta-as com `bootc switch` e passa a receber actualizacoes automaticas.

```bash
# na VM, uma vez
sudo bootc switch ghcr.io/sergiotravassos/homelab-devbox:latest
sudo systemctl reboot

# rollback, se a imagem nova for ma
sudo bootc rollback
```

O `bootc rollback` e a razao pela qual isto vale o incomodo: um arranque anterior
fica sempre disponivel, e voltar atras demora o tempo de um reboot.

## Construir no GitHub Actions

As duas imagens constroem e publicam num runner alojado. Numeros medidos na
primeira execucao verde:

| Imagem | Base | Tempo |
|---|---|---:|
| `homelab-devbox` | `quay.io/fedora/fedora-bootc:42` | ~6 min |
| `homelab-bazzite` | `ghcr.io/ublue-os/bazzite:latest` | ~33 min |

O disco nao e o constrangimento: o runner traz 145 GB de raiz e sobram ~114 GB
depois do passo de limpeza. O que custa e o tempo — a base do Bazzite e grande e
o `rpm-ostree install` reescreve uma camada inteira. Dai o `timeout-minutes: 90`,
que existe para falhar de forma limpa em vez de arrastar.

### Quando faz sentido construir noutro sitio

O CI serve de verificacao de que os `Containerfile` continuam validos. Para
iterar depressa, construir na `devbox` e mais rapido do que esperar 33 minutos
por um runner:

```bash
podman build -t ghcr.io/sergiotravassos/homelab-bazzite:latest bootc/bazzite
podman push ghcr.io/sergiotravassos/homelab-bazzite:latest
```

E a VM com 8 vCPU, 16 GB e disco local — e tem a cache das camadas entre builds,
que o runner nao tem.
