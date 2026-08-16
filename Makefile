# homelab — ponto de entrada unico.
#   make help
#
# Nenhum alvo assume que os anteriores correram na mesma sessao.
# Todos os alvos sao idempotentes: correr duas vezes nao faz nada na segunda.

SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.ONESHELL:

TOFU_DIR     := tofu/envs/lab
ANSIBLE_DIR  := ansible
PVE_HOST     ?= 10.10.10.10
PVE_USER     ?= root
PVE_SSH      := $(PVE_USER)@$(PVE_HOST)
OCP_DIR      := openshift/install/work
PROFILE_SH   := scripts/profile.sh

define check_tool
@command -v $(1) >/dev/null 2>&1 || { echo "falta $(1) — corre: mise install"; exit 1; }
endef

##@ Ajuda

.PHONY: help
help: ## Mostra esta ajuda
	@awk 'BEGIN {FS = ":.*##"; printf "\nhomelab — alvos disponiveis\n"} \
	/^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""

##@ Bootstrap do host

.PHONY: bootstrap
bootstrap: ## Prepara o Proxmox recem-instalado (repos, IOMMU, ZFS, rede, token)
	@echo "==> bootstrap de $(PVE_HOST)"
	@for s in bootstrap/proxmox/*.sh; do \
		echo "--> $$s"; \
		ssh $(PVE_SSH) 'bash -s' < "$$s"; \
	done
	@echo "==> feito. Reiniciar o host e correr 'make verify-host'."

.PHONY: verify-host
verify-host: ## Verifica IOMMU, vfio, ZFS e rede no host
	@ssh $(PVE_SSH) 'bash -s' < scripts/verify-host.sh

.PHONY: configure-host
configure-host: ## Aplica a configuracao Ansible ao proprio Proxmox
	$(call check_tool,ansible-playbook)
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/proxmox-host.yml

##@ Imagens e templates

.PHONY: template
template: ## Constroi o template Fedora cloud com Packer
	$(call check_tool,packer)
	@cd packer/fedora-cloud && packer init . && packer build .

##@ Infraestrutura (OpenTofu)

.PHONY: init
init: ## Inicializa o OpenTofu
	$(call check_tool,tofu)
	@cd $(TOFU_DIR) && tofu init -upgrade

.PHONY: fmt
fmt: ## Formata os ficheiros HCL
	@tofu fmt -recursive tofu/

.PHONY: validate
validate: ## Valida a configuracao
	@cd $(TOFU_DIR) && tofu validate

.PHONY: plan
plan: ## Mostra o que mudaria (ler sempre antes de aplicar)
	@cd $(TOFU_DIR) && tofu plan -out=tfplan

.PHONY: apply
apply: ## Aplica o plano gravado por 'make plan'
	@cd $(TOFU_DIR) && test -f tfplan || { echo "corre 'make plan' primeiro"; exit 1; }
	@cd $(TOFU_DIR) && tofu apply tfplan && rm -f tfplan

.PHONY: destroy
destroy: ## Destroi os guests geridos (pede confirmacao)
	@read -r -p "destruir TODOS os guests geridos? escreve 'sim': " a; [ "$$a" = "sim" ]
	@cd $(TOFU_DIR) && tofu destroy

##@ Configuracao (Ansible)

.PHONY: configure
configure: ## Configura todos os guests
	$(call check_tool,ansible-playbook)
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

.PHONY: configure-check
configure-check: ## Ansible em modo dry-run
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml --check --diff

.PHONY: galaxy
galaxy: ## Instala as coleccoes e papeis externos
	@cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml

##@ Perfis de memoria (ver docs/capacity.md)

.PHONY: profile-status
profile-status: ## Mostra que guests estao ligados e quanta RAM esta comprometida
	@$(PROFILE_SH) status

.PHONY: profile-idle
profile-idle: ## 12 GB — so opnsense e haos (estado por omissao)
	@$(PROFILE_SH) apply idle

.PHONY: profile-gaming
profile-gaming: ## 28 GB — a consola da sala
	@$(PROFILE_SH) apply gaming

.PHONY: profile-dev
profile-dev: ## 40 GB — devbox + Kafka + PostgreSQL
	@$(PROFILE_SH) apply dev

.PHONY: profile-platform
profile-platform: ## 48 GB — OpenShift + servicos de dados
	@$(PROFILE_SH) apply platform

.PHONY: profile-full-lab
profile-full-lab: ## 64 GB — tudo menos o gaming (ver docs/capacity.md)
	@$(PROFILE_SH) apply full-lab

##@ OpenShift

.PHONY: ocp-iso
ocp-iso: ## Gera a ISO do instalador agent-based
	@test -f $(OCP_DIR)/install-config.yaml || { echo "falta $(OCP_DIR)/install-config.yaml — ver runbook 02"; exit 1; }
	@openshift-install --dir $(OCP_DIR) agent create image
	@scp $(OCP_DIR)/agent.x86_64.iso $(PVE_SSH):/var/lib/vz/template/iso/

.PHONY: ocp-install
ocp-install: ## Espera pela conclusao da instalacao do SNO
	@openshift-install --dir $(OCP_DIR) agent wait-for bootstrap-complete
	@openshift-install --dir $(OCP_DIR) agent wait-for install-complete

.PHONY: ocp-destroy
ocp-destroy: ## Destroi a VM do cluster e limpa o estado do instalador
	@read -r -p "destruir o cluster? escreve 'sim': " a; [ "$$a" = "sim" ]
	@cd $(TOFU_DIR) && tofu destroy -target=module.ocp_sno
	@rm -rf $(OCP_DIR)

.PHONY: gitops-bootstrap
gitops-bootstrap: ## Instala o OpenShift GitOps e semeia o app-of-apps
	$(call check_tool,oc)
	@oc apply -k openshift/gitops/bootstrap/
	@echo "==> a aguardar pelo operador..."
	@oc wait --for=condition=Available deployment/openshift-gitops-server \
		-n openshift-gitops --timeout=600s
	@oc apply -f openshift/gitops/bootstrap/app-of-apps.yaml

##@ Backup

.PHONY: pbs-deploy
pbs-deploy: ## Cria e configura o Proxmox Backup Server
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/backup.yml

.PHONY: backup-verify
backup-verify: ## Verifica que os backups correram e sao legiveis
	@ssh $(PVE_SSH) 'bash -s' < scripts/backup-verify.sh

##@ Qualidade

.PHONY: lint
lint: fmt ## Corre todos os linters
	@cd $(TOFU_DIR) && tofu validate
	@tflint --recursive --chdir=tofu
	@yamllint -c .yamllint .
	@cd $(ANSIBLE_DIR) && ansible-lint .
	@shellcheck bootstrap/proxmox/*.sh scripts/*.sh

.PHONY: secrets-scan
secrets-scan: ## Procura segredos no historico e na arvore de trabalho
	@gitleaks detect --no-banner --redact --verbose

.PHONY: hooks
hooks: ## Instala os hooks de pre-commit
	@pre-commit install && pre-commit run --all-files

##@ Manutencao

.PHONY: update
update: ## Actualiza o host e as imagens (sempre por PR)
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/update.yml

.PHONY: docs
docs: ## Regenera a documentacao dos modulos OpenTofu
	@terraform-docs markdown table --output-file README.md tofu/modules/proxmox-vm
	@terraform-docs markdown table --output-file README.md tofu/modules/proxmox-lxc

.PHONY: clean
clean: ## Remove artefactos locais (nao toca em nada remoto)
	@rm -rf $(TOFU_DIR)/tfplan packer/fedora-cloud/output-* tmp/
	@find . -name '*.retry' -delete
	@echo "limpo."
