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
