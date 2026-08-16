[Português](README.md) · **English**

# homelab

**One node. Six machines. All of it in Git.**

A home lab built on Proxmox VE, with the entire infrastructure declared as code. The only thing
installed by hand is the hypervisor. From there on, every VM, every container, every firewall rule
and every OpenShift operator comes from a file version-controlled in this repository.

The point isn't to host services. It's to have somewhere to break things on purpose — a Kafka
cluster losing a broker, an idempotent consumer handed the same message twice, a GitOps rollback at
three in the morning — without anyone real paying for it.

<p align="center">
  <img src="docs/diagrams/01-hardware.svg" alt="Physical layer of the node" width="100%">
</p>

> **A note on language.** The diagrams and the deep documentation under [`docs/`](docs/) are written
> in Portuguese. This page carries the full architecture; the linked documents go further into
> detail and stay in the original. The code, comments and commit messages are Portuguese too.

---

## Contents

| Section | What it answers |
|---|---|
| [Why](#why) | What problem this lab solves |
| [Hardware](#hardware) | What's inside the box |
| [Network](#network) | How traffic is separated with a single NIC |
| [Virtualization](#virtualization) | Who gets which CPU, which RAM and which GPU |
| [Capacity](#capacity) | Why everything can't run at once |
| [Workflow](#workflow) | From the MacBook to the cluster |
| [Platform](#platform) | What runs inside OpenShift |
| [Repository layout](#repository-layout) | Where everything lives |
| [Getting started](#getting-started) | How to stand this up from nothing |
| [Conventions](#conventions) | Secrets, decisions, names |
| [Status](#status) | What works and what doesn't yet |

---

## Why

I work every day with Quarkus microservices on OpenShift, decoupled through Kafka, delivered by
Argo CD. What I don't get at work is permission to destroy the cluster on a Friday to see what
happens.

This lab exists for three things:

1. **Operating the stack from the bottom up.** Designing a distributed system and installing
   OpenShift on a single node — with its own DNS and its own storage — are different skills. This
   is the second one.
2. **Practising infrastructure as code properly.** If a machine can't be destroyed and recreated
   from the repository, it doesn't count. That's the rule that gives everything here its shape.
3. **Having a decent console in the living room.** The same hardware that compiles GraalVM native
   images in the afternoon runs Steam at night. Not to save money — because the problem of one GPU
   belonging to one VM at a time is an interesting one.

This is not a production project and the repository doesn't pretend otherwise. Where a decision was
forced by budget or by hardware, it's written down as such.

---

## Hardware

A single machine, built to run 24/7 quietly, with headroom for one heavy workload at a time.

| Component | Choice | Why |
|---|---|---|
| CPU | AMD Ryzen 9 9950X3D — 16C / 32T | Two CCDs with different profiles: CCD 0 carries the 3D V-Cache and goes to gaming, CCD 1 clocks higher and takes OpenShift and the builds |
| Motherboard | ASUS ROG Strix B850-I Gaming WiFi | Mini-ITX AM5; the x16 slot is wired straight to the CPU, which gives a clean IOMMU group for passthrough |
| RAM | Kingston FURY Beast 64 GB (2 × 32) DDR5-6000 CL30 EXPO | The scarcest resource in the lab. See [Capacity](#capacity) |
| Storage | Samsung 990 PRO 2 TB PCIe 4.0 NVMe | Single ZFS pool. The second M.2 slot is free and is the next upgrade |
| GPU | Sapphire PULSE Radeon RX 9060 XT 16 GB | Passed whole to the Bazzite VM. The 9950X3D's iGPU keeps the host console |
| Network | Realtek RTL8125 2.5 GbE | One NIC only — which is why segmentation is 802.1Q rather than physical |
| Power | Corsair SF850 (2024) 850 W SFX Platinum | Comfortable margin and a fan that stops under light load |
| Cooling | Thermalright AXP120-X67 | Air, no pump to fail in a machine that never switches off |
| Case | Fractal Design Ridge | Vertical SFF, GPU in its own thermal chamber |

Full detail, including the per-CCD core map and the thermal budget: **[docs/hardware.md](docs/hardware.md)**.

---

## Network

One network card, six broadcast domains. An 802.1Q trunk lands on a VLAN-aware Proxmox bridge and
each guest declares the tag it belongs to. The house router is not touched by this repository — if
the lab burns down, the family stays online.

<p align="center">
  <img src="docs/diagrams/02-network.svg" alt="Network blueprint and VLANs" width="100%">
</p>

| VLAN | Name | Subnet | Who lives there |
|---:|---|---|---|
| — | untagged | `192.168.1.0/24` | House LAN; OPNsense WAN leg |
| 10 | `MGMT` | `10.10.10.0/24` | Proxmox, switch management, Proxmox Backup Server |
| 20 | `PLATFORM` | `10.10.20.0/24` | OpenShift, Kafka, PostgreSQL, registry |
| 30 | `IOT` | `10.10.30.0/24` | Home Assistant and every piece of third-party firmware |
| 40 | `GAMING` | `10.10.40.0/24` | Bazzite |
| 50 | `DEV` | `10.10.50.0/24` | Development bench |

The base rule between VLANs is deny. Whatever passes is declared in `ansible/` and reviewed in a PR,
not added hastily through a web interface. The internal domain is `lab.home.arpa` — reserved by
[RFC 8375](https://www.rfc-editor.org/rfc/rfc8375.html), unlike `.local`, which collides with mDNS.

Detail, including the addressing plan and the inter-VLAN rules: **[docs/network.md](docs/network.md)**.

---

## Virtualization

<p align="center">
  <img src="docs/diagrams/03-virtualization.svg" alt="Guests, resources and passthrough" width="100%">
</p>

| Guest | System | vCPU | RAM | Disk | VLAN | Running |
|---|---|---:|---:|---:|---:|---|
| `ocp-sno` | OpenShift 4.x Single-Node (RHCOS) | 12 · CCD 1 | 24 GB | 200 GB | 20 | on demand |
| `devbox` | Fedora Silverblue (bootc) | 8 · CCD 1 | 16 GB | 150 GB | 50 | on demand |
| `bazzite` | Bazzite (Fedora Atomic) | 8 · CCD 0 pinned | 16 GB | 250 GB | 40 | on demand |
| `platform` | 3 × LXC: Kafka, PostgreSQL, registry | 6 shared | 12 GB | 100 GB | 20 | on demand |
| `haos` | Home Assistant OS | 2 | 4 GB | 32 GB | 30 | always |
| `opnsense-lab` | OPNsense | 2 | 2 GB | 20 GB | trunk | always |

Two decisions worth explaining:

**The GPU belongs to one VM at a time.** There is one PCIe slot and one card. `bazzite` gets it
whole through `vfio-pci`, along with the rear USB controller and Bluetooth. The host uses the
9950X3D's integrated graphics for its console. There is no sharing, this card has no SR-IOV, and the
repository says so instead of promising otherwise.

**The per-CCD pinning is not decorative.** The 9950X3D stacks 64 MB of cache on CCD 0 only. Pinning
the gaming VM to those cores and pushing OpenShift and the builds onto CCD 1 stops the scheduler
from throwing threads between dies — the classic problem with dual-CCD X3D parts.

---

## Capacity

The ceiling is 64 GB and there's no way around it. Rather than pretend everything fits, the lab has
boot profiles, and each profile is a `Makefile` target.

<p align="center">
  <img src="docs/diagrams/04-capacity.svg" alt="Memory profiles against the 64 GB ceiling" width="100%">
</p>

```bash
make profile-idle       # 12 GB — OPNsense and Home Assistant only
make profile-gaming     # 28 GB — the living room console
make profile-dev        # 40 GB — devbox + Kafka + PostgreSQL
make profile-platform   # 48 GB — OpenShift + data services
make profile-full-lab   # 64 GB — everything but gaming, and only with the tuning in docs/capacity.md
```

`gaming` and `platform` never coexist: together they ask for 80 GB. It's the most concrete
limitation in the lab and it's drawn rather than hidden. The way out — 2 × 48 GB — is in
**[docs/capacity.md](docs/capacity.md)**, along with the memory-speed cost it implies.

---

## Workflow

The MacBook is a terminal. It hosts nothing, compiles nothing heavy and holds no state. Losing the
laptop costs a `git clone` and restoring two keys.

<p align="center">
  <img src="docs/diagrams/05-workflow.svg" alt="Infrastructure cycle and application cycle" width="100%">
</p>

There are two cycles, and they meet at exactly one point — an image digest:

- **Infrastructure.** Edit on the Mac → PR → GitHub Actions validates (`tofu validate`, `tflint`,
  `ansible-lint`, `gitleaks`) → merge → `make apply` from the Mac against the Proxmox API → Ansible
  finishes the configuration over SSH.
- **Application.** JetBrains Gateway opens the IDE against `devbox`, where the code actually
  compiles → push → Tekton inside the cluster (or Actions when the cluster is off) → signed image in
  the registry → digest bump in the GitOps repository → Argo CD syncs.

Nothing reaches the cluster through `oc apply` from a laptop. If it isn't in Git, it doesn't exist —
and Argo CD's self-heal undoes anyone who tries. The same rule applies underneath: a VM created in
the Proxmox web interface is a VM nobody can recreate, and `tofu plan` calls it out the next day.

---

## Platform

<p align="center">
  <img src="docs/diagrams/06-platform.svg" alt="Architecture inside OpenShift" width="100%">
</p>

Inside the cluster runs a reduced version of the same design I use in production: database per
service, transactional outbox, events over Kafka, reads separated from writes.

| Layer | Choice | Note |
|---|---|---|
| Edge | Kong Gateway Operator | Auth, rate limiting and plugins declared as CRDs |
| Services | Quarkus, GraalVM native image | `orders-api`, `inventory-worker`, `query-api` |
| Events | Strimzi, KRaft mode | One broker, replica 1 — enough to practise the pattern |
| Outbox | Kafka Connect + Debezium | Reads the WAL; the application never writes to the topic directly |
| Data | CloudNativePG | One database per service, with a replica where it makes sense |
| Delivery | OpenShift GitOps (Argo CD) | App-of-apps, automated sync, self-heal, prune |
| Build | OpenShift Pipelines (Tekton) | Native build inside the cluster, Maven cache on a PVC |
| Observability | Prometheus, Grafana, OpenTelemetry, Tempo | Continuous trace from gateway to consumer, across the topic |
| Secrets | SOPS + age, External Secrets Operator | Public repository: nothing in the clear, ever |

---

## Repository layout

```
homelab/
├── bootstrap/proxmox/     # the little that's done by hand, on the host, once
├── tofu/                  # OpenTofu — VMs and LXC through the Proxmox API
│   ├── modules/           #   proxmox-vm, proxmox-lxc
│   └── envs/lab/          #   this lab's only instance
├── ansible/               # post-provisioning configuration
│   ├── inventories/lab/   #   inventory and group variables
│   ├── playbooks/         #   site.yml and one playbook per role
│   └── roles/             #   own roles
├── packer/                # Fedora cloud template build
├── bootc/                 # Containerfiles for the bootc images
│   ├── bazzite/           #   Bazzite-derived console
│   └── devbox/            #   Silverblue with the Java toolchain
├── openshift/
│   ├── install/           # agent-based installer configuration
│   └── gitops/            # Argo CD app-of-apps
├── docs/
│   ├── adr/               # architecture decisions, with the context
│   ├── runbooks/          # operational procedures
│   └── diagrams/          # the SVGs on this page
└── .github/workflows/     # PR validation
```

---

## Getting started

Prerequisite on the Mac: `mise` installs the rest.

```bash
git clone git@github.com:sergiotravassos/homelab.git && cd homelab
mise install          # tofu, ansible, packer, oc, kubectl, helm, sops, age
cp tofu/envs/lab/terraform.tfvars.example tofu/envs/lab/terraform.tfvars
```

Then, in order:

| Step | Command | Document |
|---|---|---|
| 1. Install Proxmox | *manual, from a USB stick* | [runbooks/01-bootstrap-proxmox.md](docs/runbooks/01-bootstrap-proxmox.md) |
| 2. Prepare the host | `make bootstrap` | same — IOMMU, vfio, ZFS, repositories, API token |
| 3. Build the template | `make template` | Packer, Fedora cloud image |
| 4. Provision the guests | `make plan && make apply` | OpenTofu |
| 5. Configure the guests | `make configure` | Ansible |
| 6. Install OpenShift | `make ocp-install` | [runbooks/02-install-openshift-sno.md](docs/runbooks/02-install-openshift-sno.md) |
| 7. Seed Argo CD | `make gitops-bootstrap` | app-of-apps takes it from there |

`make help` lists everything. None of these steps assumes the previous ones ran in the same session.

---

## Conventions

**Secrets.** The repository is public. Nothing in the clear, no exceptions. Sensitive values live
encrypted with [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age);
the private key never enters Git. `gitleaks` runs on every PR and fails the build. The `*.example`
files show the shape, never the content.

**Decisions.** Choices with consequences live in [`docs/adr/`](docs/adr/) in ADR format — context,
options considered, decision, and what it costs. It's the part of the repository that will still be
worth something in a year, when I no longer remember why OPNsense isn't the house router.

**Names.** Guests in lowercase with no environment suffixes — there is only one environment.
Addresses assigned per VLAN following the pattern in the table above: `.1` is always the gateway,
the rest is declared.

**Idempotency.** Any `Makefile` target can be run twice in a row. If it can't, that's a bug and not
a feature.

---

## Status

This is a work in progress, written while the hardware is still being assembled. What's here is the
decided architecture and the code skeleton that implements it.

| Area | Status |
|---|---|
| Architecture, diagrams, ADRs | designed |
| Proxmox bootstrap | written, unverified on metal |
| OpenTofu — modules and environment | written, validated against the provider schema, unverified on metal |
| Ansible — inventory and roles | skeleton |
| bootc images — Bazzite and devbox | skeleton |
| OpenShift SNO installation | documented, not yet run |
| Argo CD app-of-apps | skeleton |
| GPU passthrough | unverified on metal |

The detailed roadmap, with what comes next and what was deliberately left out, is in
**[docs/roadmap.md](docs/roadmap.md)**.

---

## License

[MIT](LICENSE). Copy freely — if anything here saves you a weekend, it was worth writing.
