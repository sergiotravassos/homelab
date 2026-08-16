# 0004 — iGPU para o host, dGPU inteira para o guest

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

A máquina tem uma placa gráfica dedicada (RX 9060 XT) e um slot PCIe x16. O 9950X3D traz gráficos
integrados. Uma das VMs é uma Steam Machine ligada à televisão, que precisa de desempenho gráfico
real e de latência baixa.

## Opções consideradas

| Opção | Viável | Notas |
|---|---|---|
| **Passthrough completo da dGPU, iGPU para o host** | ✅ | Desempenho nativo no guest; consola do host sempre disponível |
| **SR-IOV / vGPU** | ❌ | Não suportado nesta placa. É funcionalidade de placas profissionais |
| **VirGL / VirtIO-GPU Venus** | ⚠️ | Aceleração parcial, imatura para jogos; sem saída HDMI directa |
| **Sem GPU dedicada, streaming a partir de outra máquina** | ⚠️ | Elimina o problema mas também o objectivo |
| **Passar a iGPU e deixar a dGPU no host** | ❌ | Ao contrário do que interessa: a carga pesada é a do guest |

## Decisão

A **dGPU é passada inteira** à VM `bazzite` via `vfio-pci`, junto com a sua função de áudio HDMI e um
controlador USB completo. O **host usa a iGPU** para a consola.

O `Primary Video Adapter` da BIOS fica em `Integrated`, para que o host nunca reclame a dGPU no
arranque.

Passa-se um controlador USB inteiro em vez de portas individuais: assim os comandos podem ser
ligados e desligados a quente sem alterar a configuração da VM.

## Consequências

**Positivas**

- Desempenho gráfico nativo, sem camada de tradução.
- HDMI directo para a televisão: sem latência de compressão.
- A consola do host continua acessível mesmo com o guest a correr — o que salva a vida quando a rede
  está mal configurada.

**Negativas**

- **A GPU pertence a uma VM de cada vez.** Não há partilha e não há segunda placa: só existe um slot
  x16. Qualquer carga futura de compute GPU — inferência local de LLM é a candidata óbvia — entra em
  conflito directo com a `bazzite`.
- Depende de a GPU ficar sozinha no seu grupo IOMMU. Se não ficar, a resposta é mudar o dispositivo
  intruso de slot. **O patch ACS fica excluído**: desactiva um isolamento real em troca de
  conveniência, e num nó que corre a automação da casa isso não se justifica.
- Adiciona parâmetros de kernel e blacklists de módulos ao host — mais superfície para partir numa
  actualização. Mitigação: o estado é gerido pelo Ansible e verificado após cada actualização.
- O historial de *reset bug* das GPU AMD obriga a validar o ciclo de reinício da VM antes de dar o
  passthrough por assente.
