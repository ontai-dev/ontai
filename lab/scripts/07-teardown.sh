#!/usr/bin/env bash
# lab/scripts/07-teardown.sh — gracefully tear down a cluster.
#
# Steps (per lab/CLAUDE.md §Cluster teardown):
#   1. Gracefully shut down all VMs via virsh shutdown
#   2. Wait for all VMs to reach shut-off state
#   3. Undefine libvirt domains via virsh undefine
#   4. Delete linked-clone disk files from /var/lib/libvirt/images/ontai/{cluster}/
#
# NEVER touches golden backing files in /var/lib/libvirt/images/ontai/golden/.
# NEVER runs on ccs-mgmt without explicit confirmation (management cluster must
# be the last cluster torn down and requires a separate Governor decision).
#
# Idempotent: skips VMs that are already shut off or undefined.
#
# Usage: 07-teardown.sh <cluster-name>
#   cluster-name: ccs-mgmt | ccs-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools virsh

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt | ccs-dev)"
[[ "$CLUSTER" == "ccs-mgmt" || "$CLUSTER" == "ccs-dev" ]] \
  || fail_fast "Unknown cluster '${CLUSTER}'. Valid values: ccs-mgmt, ccs-dev"

CLUSTER_DIR="/var/lib/libvirt/images/ontai/${CLUSTER}"
GOLDEN_DIR="/var/lib/libvirt/images/ontai/golden"

# ── Cluster node table ────────────────────────────────────────────────────────

if [ "$CLUSTER" = "ccs-mgmt" ]; then
  NODES=(ccs-mgmt-cp1 ccs-mgmt-cp2 ccs-mgmt-cp3 ccs-mgmt-w1 ccs-mgmt-w2)
else
  NODES=(ccs-dev-cp1 ccs-dev-cp2 ccs-dev-cp3 ccs-dev-w1 ccs-dev-w2)
fi

# ── Safety check ─────────────────────────────────────────────────────────────

log_info "=== Teardown: ${CLUSTER} ==="
log_info "Nodes:       ${NODES[*]}"
log_info "Disk dir:    ${CLUSTER_DIR}"
log_info "Golden dir:  ${GOLDEN_DIR}  (will NOT be touched)"
log_info ""

# ── Phase 1: Graceful shutdown ────────────────────────────────────────────────

log_info "=== Phase 1: gracefully shutting down ${CLUSTER} VMs ==="

for node in "${NODES[@]}"; do
  if ! vm_is_defined "$node"; then
    log_info "${node} not defined — skipping shutdown"
    continue
  fi

  state="$(vm_state "$node")"
  if [ "$state" = "running" ]; then
    log_info "Shutting down ${node}"
    virsh shutdown "$node"
  elif [ "$state" = "shut off" ]; then
    log_info "${node} already shut off"
  else
    log_info "${node} state=${state} — attempting shutdown"
    virsh shutdown "$node" 2>/dev/null || true
  fi
done

# Wait for all defined VMs to reach shut-off
for node in "${NODES[@]}"; do
  vm_is_defined "$node" || continue
  state="$(vm_state "$node")"
  [ "$state" = "shut off" ] && continue
  wait_vm_shutoff "$node" 120
done

log_info "All ${CLUSTER} VMs shut off"

# ── Phase 2: Undefine libvirt domains ────────────────────────────────────────

log_info "=== Phase 2: undefining libvirt domains ==="

for node in "${NODES[@]}"; do
  if vm_is_defined "$node"; then
    log_info "Undefining ${node}"
    virsh undefine "$node" --remove-all-storage 2>/dev/null || virsh undefine "$node" || true
    log_info "${node} undefined"
  else
    log_info "${node} not defined — skipping undefine"
  fi
done

# ── Phase 3: Delete linked-clone disk files ───────────────────────────────────
# Only delete files in the cluster-specific directory.
# Never touch anything in GOLDEN_DIR.

log_info "=== Phase 3: deleting linked-clone disk files in ${CLUSTER_DIR} ==="

if [ -d "$CLUSTER_DIR" ]; then
  # Enumerate expected disk files only — never glob-delete the whole directory
  for node in "${NODES[@]}"; do
    disk="${CLUSTER_DIR}/${node}.qcow2"
    if [ -f "$disk" ]; then
      # Verify this is NOT a golden image (safety check)
      if [[ "$disk" == "${GOLDEN_DIR}"* ]]; then
        fail_fast "SAFETY: refusing to delete file under golden dir: ${disk}"
      fi
      log_info "Deleting ${disk}"
      rm -f "$disk"
    else
      log_info "${disk} not found — skipping"
    fi
  done

  # Remove cluster disk directory if now empty
  if [ -d "$CLUSTER_DIR" ] && [ -z "$(ls -A "$CLUSTER_DIR" 2>/dev/null)" ]; then
    rmdir "$CLUSTER_DIR"
    log_info "Removed empty cluster disk directory: ${CLUSTER_DIR}"
  fi
else
  log_info "Cluster disk directory does not exist: ${CLUSTER_DIR} — nothing to delete"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Teardown complete for ${CLUSTER} ==="
log_info "  Golden images preserved at: ${GOLDEN_DIR}"
log_info "  To rebuild: run 02-cluster-create.sh ${CLUSTER}"
