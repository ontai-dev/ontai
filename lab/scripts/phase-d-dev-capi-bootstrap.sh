#!/usr/bin/env bash
# lab/scripts/phase-d-dev-capi-bootstrap.sh -- Phase D: ccs-dev CAPI bootstrap.
#
# DESTRUCTIVE: Tears down ccs-dev, restores golden images, starts VMs in CAPI
# mode (maintenance mode only, no machineconfig push). The CAPI Platform operator
# on ccs-mgmt delivers machineconfigs via TalosCluster CR after VMs are running.
#
# Requires human confirmation unless CONFIRM_DESTRUCTIVE=yes is set.
#
# Prerequisites:
#   - ccs-mgmt must be up with Platform operator running
#   - Golden images must exist in /var/lib/libvirt/images/ontai/golden/
#   - ccs-dev TalosCluster CR must exist in configs/ccs-dev/compiled/bootstrap/
#
# Usage:
#   CONFIRM_DESTRUCTIVE=yes bash phase-d-dev-capi-bootstrap.sh
#
# Environment:
#   MGMT_KUBECONFIG      path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   CONFIRM_DESTRUCTIVE  must be "yes" to proceed past the gate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
KUBECTL_MGMT="kubectl --kubeconfig ${MGMT_KUBECONFIG}"
DEV_CR="${SCRIPT_DIR}/../configs/ccs-dev/compiled/bootstrap/ccs-dev.yaml"
START_TS=$(date +%s)

fail_phase() {
  local step="$1"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "FAIL [phase-d] step=${step} elapsed=${elapsed}s" >&2
  exit 1
}

pass_phase() {
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "PASS [phase-d] elapsed=${elapsed}s"
}

# ── Destructive gate ──────────────────────────────────────────────────────────

if [ "${CONFIRM_DESTRUCTIVE:-}" != "yes" ]; then
  echo "STOP [phase-d] HUMAN-AT-BOUNDARY: destructive operation requires confirmation." >&2
  echo "" >&2
  echo "  Phase D tears down ccs-dev completely and rebuilds from golden images." >&2
  echo "  CAPI Platform operator delivers machineconfigs. All existing ccs-dev" >&2
  echo "  data will be lost." >&2
  echo "" >&2
  echo "  To proceed: CONFIRM_DESTRUCTIVE=yes bash phase-d-dev-capi-bootstrap.sh" >&2
  exit 1
fi

log_info "phase-d CONFIRM_DESTRUCTIVE=yes -- proceeding with CAPI bootstrap"

# ── Step 1: Tear down ccs-dev ─────────────────────────────────────────────────

log_info "phase-d step=1 Tearing down ccs-dev"
bash "${SCRIPT_DIR}/07-teardown.sh" ccs-dev || fail_phase "teardown-ccs-dev"

# ── Step 2: Start VMs in CAPI mode ────────────────────────────────────────────

log_info "phase-d step=2 Starting ccs-dev VMs (CAPI mode -- maintenance mode only)"
MODE=capi bash "${SCRIPT_DIR}/dev-up.sh" ccs-dev || fail_phase "dev-up-capi"
log_info "  VMs in maintenance mode (port 50000). Waiting for CAPI machineconfig delivery."

# ── Step 3: Apply ccs-dev TalosCluster CR ────────────────────────────────────

log_info "phase-d step=3 Applying ccs-dev TalosCluster CR to management cluster"
[ -f "$DEV_CR" ] || fail_phase "ccs-dev-cr-missing-at-${DEV_CR}"
$KUBECTL_MGMT apply --server-side --force-conflicts -f "$DEV_CR" \
  || fail_phase "apply-ccs-dev-taloscluster"

# ── Step 4: Wait for TalosCluster Ready ───────────────────────────────────────

log_info "phase-d step=4 Waiting for TalosCluster ccs-dev Ready (max 10 min)"
for i in $(seq 1 120); do
  ready=$($KUBECTL_MGMT get taloscluster ccs-dev -n seam-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [ "$ready" = "True" ]; then
    log_info "  TalosCluster ccs-dev Ready=True"
    break
  fi
  phase_val=$($KUBECTL_MGMT get taloscluster ccs-dev -n seam-system \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  log_info "  phase=${phase_val} (attempt ${i}/120) -- sleeping 5s"
  if [ "$i" = "120" ]; then
    log_info "  WARN: TalosCluster not Ready after 10 min -- proceeding to acceptance tests"
  fi
  sleep 5
done

# ── Step 5: AC-2 acceptance contract ──────────────────────────────────────────

log_info "phase-d step=5 Running AC-2 (wrapper e2e)"
export MGMT_KUBECONFIG
export TENANT_KUBECONFIG="${HOME}/.kube/ccs-dev.yaml"
(cd "${SCRIPT_DIR}/../../wrapper" && make e2e) || fail_phase "ac2-wrapper-e2e"
log_info "  AC-2 PASS"

pass_phase
