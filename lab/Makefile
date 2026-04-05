# lab/Makefile — top-level targets for ontai lab provisioning.
#
# Prerequisites: virsh, qemu-img, talosctl, kubectl, nc
# All scripts are idempotent — safe to re-run.
#
# Usage:
#   make golden                    — create golden images (run once per Talos version)
#   make cluster-up                — bring up ccs-mgmt (steps 02-05)
#   make teardown CLUSTER=ccs-mgmt — tear down a cluster
#   make teardown CLUSTER=ccs-dev  — tear down a cluster
#   make dev-up                    — bring up ccs-dev (steps 02-05)

SHELL := /bin/bash
SCRIPTS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts

# ── Tool check ────────────────────────────────────────────────────────────────

REQUIRED_TOOLS := virsh qemu-img talosctl kubectl nc

.PHONY: check-tools
check-tools:
	@missing=""; \
	for tool in $(REQUIRED_TOOLS); do \
	  command -v "$$tool" >/dev/null 2>&1 || missing="$$missing $$tool"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "ERROR: missing required tools:$$missing" >&2; \
	  exit 1; \
	fi

# ── golden ────────────────────────────────────────────────────────────────────
# Create golden images from Talos ISO. Run once per Talos version upgrade.
# Writes golden QCOW2 images and CHECKSUMS to /var/lib/libvirt/images/ontai/golden/.

.PHONY: golden
golden: check-tools
	@echo "==> [golden] Creating golden images from Talos ISO"
	@bash "$(SCRIPTS)/01-golden-create.sh"

# ── cluster-up ────────────────────────────────────────────────────────────────
# Bring up ccs-mgmt through Kubernetes API availability.
# Steps: 02-cluster-create → 03-cluster-start → 04-machineconfig-apply → 05-bootstrap
#
# After cluster-up completes, run compiler bootstrap, compiler launch, and
# compiler enable from your workstation to generate the deployment bundle, then
# apply each phase in order per the compiler enable output directory.

.PHONY: cluster-up
cluster-up: check-tools
	@echo "==> [cluster-up] Creating ccs-mgmt linked clones"
	@bash "$(SCRIPTS)/02-cluster-create.sh" ccs-mgmt
	@echo "==> [cluster-up] Starting ccs-mgmt VMs"
	@bash "$(SCRIPTS)/03-cluster-start.sh" ccs-mgmt
	@echo "==> [cluster-up] Applying machine configs to ccs-mgmt"
	@bash "$(SCRIPTS)/04-machineconfig-apply.sh" ccs-mgmt
	@echo "==> [cluster-up] Bootstrapping ccs-mgmt"
	@bash "$(SCRIPTS)/05-bootstrap.sh" ccs-mgmt

# ── teardown ──────────────────────────────────────────────────────────────────
# Tear down a cluster. Pass CLUSTER=ccs-mgmt or CLUSTER=ccs-dev.
# Example: make teardown CLUSTER=ccs-dev

CLUSTER ?=

.PHONY: teardown
teardown: check-tools
	@if [ -z "$(CLUSTER)" ]; then \
	  echo "ERROR: CLUSTER is required. Usage: make teardown CLUSTER=ccs-mgmt|ccs-dev" >&2; \
	  exit 1; \
	fi
	@echo "==> [teardown] Tearing down $(CLUSTER)"
	@bash "$(SCRIPTS)/07-teardown.sh" "$(CLUSTER)"

# ── dev-up ────────────────────────────────────────────────────────────────────
# Bring up ccs-dev through Kubernetes API availability.
# ccs-mgmt must be up. ccs-test must be off (max 10 VMs total).
# Steps: 02-cluster-create → 03-cluster-start → 04-machineconfig-apply → 05-bootstrap

.PHONY: dev-up
dev-up: check-tools
	@echo "==> [dev-up] Creating ccs-dev linked clones"
	@bash "$(SCRIPTS)/02-cluster-create.sh" ccs-dev
	@echo "==> [dev-up] Starting ccs-dev VMs"
	@bash "$(SCRIPTS)/03-cluster-start.sh" ccs-dev
	@echo "==> [dev-up] Applying machine configs to ccs-dev"
	@bash "$(SCRIPTS)/04-machineconfig-apply.sh" ccs-dev
	@echo "==> [dev-up] Bootstrapping ccs-dev"
	@bash "$(SCRIPTS)/05-bootstrap.sh" ccs-dev

# ── help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "ontai lab provisioning targets:"
	@echo ""
	@echo "  make golden                    — create golden images (step 01)"
	@echo "  make cluster-up                — bring up ccs-mgmt (steps 02-05)"
	@echo "  make teardown CLUSTER=<name>   — tear down ccs-mgmt or ccs-dev (step 07)"
	@echo "  make dev-up                    — bring up ccs-dev (steps 02-05)"
	@echo ""
	@echo "Required tools: $(REQUIRED_TOOLS)"
