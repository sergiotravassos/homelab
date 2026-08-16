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

## Construir no GitHub Actions — e o seu limite

O `devbox` deriva de `fedora-bootc` e constroi sem problemas num runner alojado.

A `bazzite` e outra historia: a imagem base ronda os 20 GB descomprimida e o
runner alojado traz cerca de 14 GB livres. O workflow liberta o que pode antes
de comecar, corre as duas imagens em serie e tem um limite de 90 minutos — mas
esta e uma construcao no limite do que um runner gratuito aguenta.

Se falhar por espaco ou por tempo, as saidas, por ordem de preferencia:

1. **Construir na `devbox`** e empurrar para o `ghcr.io` a partir dali. E a VM
   com 8 vCPU, 16 GB e disco a serio — e o sitio natural para isto.
   ```bash
   podman build -t ghcr.io/sergiotravassos/homelab-bazzite:latest bootc/bazzite
   podman push ghcr.io/sergiotravassos/homelab-bazzite:latest
   ```
2. **Usar o Bazzite oficial sem camada propria.** A imagem `ghcr.io/ublue-os/bazzite`
   ja traz tudo menos o `qemu-guest-agent`, que se pode instalar com
   `rpm-ostree install` na propria VM. Perde-se o "tudo em codigo" nesse ponto —
   e ficaria registado como tal.
3. **Runner com mais disco.** Resolve, custa dinheiro, e este lab nao tem
   orcamento de CI.

A opcao 1 e a que o roadmap assume. O CI serve de verificacao de que o
`Containerfile` continua valido, nao como unico caminho de construcao.
