# ─── Cartão de leitura ────────────────────────────────────────────────────────
#  O QUE FAZ      Cria uma máquina virtual no Proxmox. É o motor do repositório:
#                 cinco dos seis guests nascem deste ficheiro.
#  PORQUE EXISTE  Sem módulo, as definições das cinco VMs repetiriam os mesmos
#                 quarenta campos cinco vezes. Uma correcção teria de ser feita
#                 em cinco sítios e esquecer-se-ia num.
#  SE TIRARES     Nada é criado. Este ficheiro é o único sítio do repositório que
#                 sabe falar de VMs com o Proxmox.
#  ONDE APRENDER  docs/percurso.md — etapa 2. Deixa este ficheiro para o fim
#                 dessa etapa: é o mais difícil, e faz muito mais sentido depois
#                 de ler o haos.tf.
# ──────────────────────────────────────────────────────────────────────────────
#
#  COMO LER ISTO
#  Um "resource" é uma coisa que passa a existir. Tudo o que está lá dentro são
#  as propriedades dessa coisa. Onde vês `var.algo`, é um valor que vem de fora
#  — de quem chama o módulo (ver haos.tf, bazzite.tf, etc.).
#
#  Há dois padrões de sintaxe que aparecem muito e convém reconhecer:
#
#    dynamic "bloco" { for_each = ... }   → cria o bloco zero ou mais vezes.
#                                           É o "if" do OpenTofu: for_each sobre
#                                           uma lista vazia significa "não criar".
#
#    condição ? a : b                     → se a condição for verdadeira usa a,
#                                           senão usa b. Igual a Java.
# ──────────────────────────────────────────────────────────────────────────────

# `locals` são valores calculados uma vez e reutilizados abaixo. Existem só para
# não repetir a mesma condição em três sítios e depois esquecer um.
locals {
  needs_efi = var.bios == "ovmf"
  is_cloned = var.clone_vm_id != null
}

resource "proxmox_virtual_environment_vm" "this" {

  # ── Identidade ──────────────────────────────────────────────────────────────
  # O vm_id é fixo e atribuído por gama (ver locals.tf do ambiente). Fixo, e não
  # automático, porque o instalador do OpenShift e as reservas de DHCP dependem
  # de o guest ter sempre o mesmo número.
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description

  # A etiqueta "opentofu" aparece na interface web. Serve para tu saberes, ao
  # olhar para a UI, que aquele guest não deve ser editado à mão.
  tags = concat(["opentofu"], var.tags)

  # ── Firmware e chipset ──────────────────────────────────────────────────────
  # q35 é um chipset moderno que expõe uma topologia PCIe real ao guest. O
  # alternativo (i440fx) é de 1996 e não serve para passthrough.
  machine = var.machine

  # seabios = BIOS clássica. ovmf = UEFI. GPUs modernas exigem UEFI.
  bios = var.bios

  # virtio-scsi-single dá uma fila por disco, o que permite iothread (abaixo).
  scsi_hardware = "virtio-scsi-single"

  # ── Estado de arranque ──────────────────────────────────────────────────────
  # started = false: o OpenTofu cria a VM mas não a liga. Ligar é decisão dos
  # perfis de memória (scripts/profile.sh), não do provisionamento.
  started = var.started

  # on_boot: arranca automaticamente com o host. Só true para os guests
  # sempre-ligados (opnsense e haos).
  on_boot = var.on_boot

  # Desliga a VM com jeito antes de a destruir, em vez de lhe cortar a corrente.
  stop_on_destroy = true

  # ── Agente do guest ─────────────────────────────────────────────────────────
  # O qemu-guest-agent corre DENTRO da VM e deixa o Proxmox pedir um shutdown
  # limpo e saber o IP. Desligado nas appliances fechadas (haos) e no RHCOS,
  # onde não o podemos instalar.
  #
  # trim = true: quando apagas ficheiros dentro da VM, o espaço é devolvido ao
  # ZFS em vez de ficar reservado para sempre.
  agent {
    enabled = var.cloud_init_enabled
    trim    = true
  }

  operating_system {
    type = var.os_type # l26 = qualquer Linux com kernel 2.6+
  }

  # ── CPU ─────────────────────────────────────────────────────────────────────
  # type = "host" passa as instruções todas do CPU real ao guest, sem máscara.
  # Perde-se a possibilidade de migrar para outra máquina — irrelevante num nó só.
  #
  # affinity é o pinning: restringe este guest a um conjunto de CPUs do host,
  # no formato do taskset (ex.: "0-7,16-23"). É como se atribui a bazzite aos
  # cores com 3D V-Cache. Ver docs/hardware.md.
  cpu {
    cores    = var.cores
    sockets  = 1
    type     = var.cpu_type
    affinity = var.cpu_affinity == "" ? null : var.cpu_affinity
  }

  # ── Memória ─────────────────────────────────────────────────────────────────
  # dedicated = o máximo. floating = o mínimo com ballooning.
  #
  # Ballooning é o host poder reclamar RAM de um guest quando precisa. Soa bem e
  # é perigoso: o OpenShift reporta-se saudável enquanto entrega latências
  # absurdas. Por isso floating = 0 (desligado) no ocp-sno e na bazzite.
  #
  # hugepages: páginas de memória de 1 GB em vez de 4 KB. Reduz a pressão na TLB
  # do CPU e é mensurável em jogos. Obriga a memória fixa — daí exigir floating = 0.
  memory {
    dedicated      = var.memory_mb
    floating       = var.memory_floating_mb
    hugepages      = var.hugepages
    keep_hugepages = var.hugepages != null
  }

  # ── Disco ───────────────────────────────────────────────────────────────────
  # Cada VM recebe um zvol — um disco virtual em bruto sobre o ZFS.
  #
  #   ssd = true      diz ao guest que o disco é sólido (muda o escalonador de I/O)
  #   discard = "on"  espaço apagado no guest é libertado no ZFS (par do trim acima)
  #   iothread        dá a este disco a sua própria thread de I/O, em vez de
  #                   competir com a emulação do resto da VM
  #   cache = "none"  o ZFS já tem a ARC; uma segunda cache por cima só duplica
  #                   RAM e arrisca perder escritas numa falha de energia
  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
    cache        = "none"
  }

  # Uma VM UEFI precisa de um pequeno disco onde guardar as variáveis de firmware.
  # Criado só quando bios = "ovmf" — é para isso que serve o dynamic.
  #
  # pre_enrolled_keys = false desliga as chaves de Secure Boot da Microsoft, que
  # entram em conflito com drivers de GPU não assinados.
  dynamic "efi_disk" {
    for_each = local.needs_efi ? [1] : []
    content {
      datastore_id      = var.datastore_id
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = false
    }
  }

  # ── Rede ────────────────────────────────────────────────────────────────────
  # Atenção à sintaxe: isto é uma LISTA (com = e [ ]), não um bloco. O provider
  # define network_device como atributo, e por isso exige que todos os campos do
  # objecto apareçam, mesmo os que ficam a null. Foi o erro que o `tofu validate`
  # apanhou quando este ficheiro foi escrito.
  #
  # vlan_id = null significa "sem etiqueta" — é o modo flat da fase 1.
  # A bridge é sempre vmbr0: há uma só, e é VLAN-aware. Ver docs/network.md.
  #
  # queues: várias filas de rede em paralelo. Só ajuda com vários vCPU, daí a
  # condição.
  network_device = [{
    bridge       = "vmbr0"
    model        = "virtio" # driver paravirtualizado: muito mais rápido que emular uma NIC real
    vlan_id      = var.vlan_id
    mac_address  = var.mac_address
    queues       = var.cores > 4 ? 4 : 1
    firewall     = false # a firewall é do OPNsense, não do Proxmox
    enabled      = true
    disconnected = false
    mtu          = null
    rate_limit   = null
    trunks       = null
  }]

  # ── Ordem de arranque ───────────────────────────────────────────────────────
  # order: menor arranca primeiro. O opnsense é 1 porque sem ele não há DNS de
  # lab. up_delay: segundos a esperar antes de arrancar o guest seguinte.
  dynamic "startup" {
    for_each = var.startup == null ? [] : [var.startup]
    content {
      order      = startup.value.order
      up_delay   = startup.value.up_delay
      down_delay = startup.value.down_delay
    }
  }

  # ── De onde vem o sistema operativo ─────────────────────────────────────────
  # Duas vias possíveis, mutuamente exclusivas:
  #
  #   clone  → copia um template já pronto (rápido; é como nasce o devbox)
  #   cdrom  → arranca de uma ISO e instala (é como nasce o ocp-sno)
  #
  # full = true faz uma cópia independente. Sem isso seria um clone ligado ao
  # template, e apagar o template levaria a VM com ele.
  dynamic "clone" {
    for_each = local.is_cloned ? [1] : []
    content {
      vm_id = var.clone_vm_id
      full  = true
    }
  }

  dynamic "cdrom" {
    for_each = var.iso_file_id == null ? [] : [1]
    content {
      file_id = var.iso_file_id
    }
  }

  # ── cloud-init ──────────────────────────────────────────────────────────────
  # O cloud-init corre no primeiro arranque de uma imagem cloud e configura
  # hostname, rede, utilizador e chaves SSH. É o que torna um template genérico
  # numa máquina específica sem ninguém tocar num teclado.
  #
  # Desligado onde não se aplica: appliances fechadas (haos), FreeBSD (opnsense)
  # e RHCOS (que usa Ignition — o equivalente da Red Hat, ver etapa 6).
  dynamic "initialization" {
    for_each = var.cloud_init_enabled ? [1] : []
    content {
      datastore_id = var.datastore_id
      interface    = "ide2" # o cloud-init é entregue como um CD virtual

      ip_config {
        ipv4 {
          address = var.ipv4_address
          gateway = var.ipv4_address == "dhcp" ? null : var.ipv4_gateway
        }
      }

      user_account {
        username = var.username
        keys     = var.ssh_public_keys
      }
    }
  }

  # ── Passthrough PCI ─────────────────────────────────────────────────────────
  # Entrega um dispositivo físico directamente ao guest. O host deixa de o ver.
  #
  #   pcie   = true   expõe-no como PCIe e não como PCI legado (exige q35)
  #   rombar = true   deixa o guest ler a ROM da placa, necessário para o vídeo
  #   xvga   = true   marca-o como a placa gráfica primária do guest
  #
  # A lista chega vazia por omissão. Isso é deliberado: os endereços PCI só se
  # sabem no metal, e um valor inventado aqui daria um ecrã preto sem pista.
  # Ver docs/gpu-passthrough.md e a etapa 5.
  dynamic "hostpci" {
    for_each = { for d in var.hostpci_devices : d.device => d }
    content {
      device = hostpci.value.device
      id     = hostpci.value.id
      pcie   = hostpci.value.pcie
      rombar = hostpci.value.rombar
      xvga   = hostpci.value.xvga
    }
  }

  # Passa-se um controlador USB inteiro, não portas individuais — assim os
  # comandos ligam e desligam a quente sem alterar a configuração da VM.
  dynamic "usb" {
    for_each = { for i, d in var.usb_devices : i => d }
    content {
      host = usb.value.host
      usb3 = usb.value.usb3
    }
  }

  # ── Fronteira com os perfis de memória ──────────────────────────────────────
  # lifecycle/ignore_changes diz ao OpenTofu "não olhes para este campo".
  #
  # Sem isto haveria uma guerra: o `make profile-dev` liga a devbox, e o `tofu
  # plan` seguinte diria "esta VM devia estar desligada, vou desligá-la". Cada
  # apply desfazia o último perfil.
  #
  # A regra que isto codifica: o OpenTofu decide o que EXISTE, os perfis decidem
  # o que está LIGADO.
  lifecycle {
    ignore_changes = [started]
  }
}
