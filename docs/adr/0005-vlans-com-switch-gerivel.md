# 0005 — Segmentação 802.1Q, adoptada por fases

**Estado:** Aceite · **Data:** 2026-08-16

## Contexto

O lab junta, na mesma máquina física, coisas com níveis de confiança muito diferentes: um plano de
gestão que controla tudo, serviços de dados, dispositivos IoT com firmware de terceiros, uma consola
de jogos e uma bancada de desenvolvimento.

A máquina tem **uma** placa de rede.

Há ainda um constrangimento não técnico: o router de casa serve a família. Um lab que derrube a
Internet doméstica é um lab que deixa de ser autorizado.

## Opções consideradas

| Opção | Notas |
|---|---|
| **802.1Q num switch gerível, bridge VLAN-aware** | Segmentação real com uma NIC; requer comprar o switch |
| **Rede plana** | Zero custo, zero configuração; zero isolamento — o IoT vê o plano de gestão |
| **Várias NIC USB** | Evita o switch; adiciona pontos de falha e drivers duvidosos num nó 24/7 |
| **Substituir o router de casa pelo OPNsense** | Elegante em papel; faz do lab um ponto único de falha para a família |
| **SDN do Proxmox com redes isoladas** | Bom para tráfego entre guests; não isola nada do que está fora da máquina |

## Decisão

**802.1Q com switch gerível**, com o OPNsense como router-on-a-stick **apenas do laboratório**. O
router de casa não é tocado.

Como o switch ainda não existe, a adopção é faseada e o repositório suporta os dois modos através de
`network_mode` em `group_vars`:

| Fase | `network_mode` | Estado |
|---|---|---|
| 1 | `flat` | Guests sem etiqueta na LAN de casa. DNS do lab num LXC com `dnsmasq`. OPNsense desligado |
| 2 | `vlan` | Trunk configurado, OPNsense a encaminhar, matriz de fluxo aplicada |

A fase 1 é explicitamente um degrau, não um destino: funciona, mas não demonstra nada sobre
segmentação.

## Consequências

**Positivas**

- Seis domínios de broadcast a partir de uma única placa.
- O IoT fica fechado: se uma lâmpada for comprometida, chega à VLAN 30 e para aí.
- As regras inter-VLAN passam a ser código revisto em PR, não cliques num assistente.
- A família mantém a Internet quando o lab estiver em baixo.

**Negativas**

- Exige comprar hardware. É a única dependência de compra bloqueante do roadmap.
- O OPNsense passa a ser peça sempre ligada: sem ele não há DNS de lab nem encaminhamento entre
  VLANs. Custa 2 GB de RAM permanentes.
- Toda a segmentação assenta num único link físico. Um cabo mau derruba tudo — mas isso já era
  verdade com uma NIC.
- Configuração do switch fica fora do Git; não há gestão declarativa razoável para switches deste
  escalão. Mitigação: a configuração está escrita em [`network.md`](../network.md) e o backup do
  switch é exportado com os restantes.
