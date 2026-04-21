#!/usr/bin/env bash
# lab/scripts/phase-c-dev-native-bootstrap.sh -- Phase C: ccs-dev ONT-native bootstrap.
#
# DESTRUCTIVE: Tears down ccs-dev, restores golden images, runs full native bootstrap
# (machineconfig push + etcd bootstrap). Requires human confirmation unless
# CONFIRM_DESTRUCTIVE=yes is set.
#
# Prerequisites:
#   - ccs-mgmt must be up
#   - Golden images must exist in /var/lib/libvirt/images/ontai/golden/
#   - ccs-dev must be torn down or CONFIRM_DESTRUCTIVE=yes acknowledges data loss
#
# Usage:
#   CONFIRM_DESTRUCTIVE=yes bash phase-c-dev-native-bootstrap.sh
#
# Environment:
#   MGMT_KUBECONFIG      path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   CONFIRM_DESTRUCTIVE  must be "yes" to proceed past the gate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
KUBECTL_MGMT="kubectl --kubeconfig ${MGMT_KUBECONFIG}"
START_TS=$(date +%s)

fail_phase() {
  local step="$1"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "FAIL [phase-c] step=${step} elapsed=${elapsed}s" >&2
  exit 1
}

pass_phase() {
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "PASS [phase-c] elapsed=${elapsed}s"
}

# ── Destructive gate ──────────────────────────────────────────────────────────

if [ "${CONFIRM_DESTRUCTIVE:-}" != "yes" ]; then
  echo "STOP [phase-c] HUMAN-AT-BOUNDARY: destructive operation requires confirmation." >&2
  echo "" >&2
  echo "  Phase C tears down ccs-dev completely and rebuilds from golden images." >&2
  echo "  All existing ccs-dev data will be lost." >&2
  echo "" >&2
  echo "  To proceed: CONFIRM_DESTRUCTIVE=yes bash phase-c-dev-native-bootstrap.sh" >&2
  exit 1
fi

log_info "phase-c CONFIRM_DESTRUCTIVE=yes -- proceeding with native bootstrap"

# ── Step 1: Tear down ccs-dev ─────────────────────────────────────────────────

log_info "phase-c step=1 Tearing down ccs-dev"
bash "${SCRIPT_DIR}/07-teardown.sh" ccs-dev || fail_phase "teardown-ccs-dev"

# ── Step 2: Full native bootstrap ─────────────────────────────────────────────

log_info "phase-c step=2 Bootstrapping ccs-dev (ONT-native mode)"
MODE=bootstrap bash "${SCRIPT_DIR}/dev-up.sh" ccs-dev || fail_phase "dev-up-bootstrap"

# ── Step 3: Verify cluster health ─────────────────────────────────────────────

log_info "phase-c step=3 Verifying ccs-dev node health"
DEV_KUBECONFIG="${HOME}/.kube/ccs-dev.yaml"
if [ -f "$DEV_KUBECONFIG" ]; then
  KUBECTL_DEV="kubectl --kubeconfig ${DEV_KUBECONFIG}"
  log_info "  waiting for nodes (max 3 min)"
  for i in $(seq 1 36); do
    count=$($KUBECTL_DEV get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$count" -ge 5 ]; then
      log_info "  ${count} nodes present"
      break
    fi
    log_info "  nodes present=${count} (attempt ${i}/36) -- sleeping 5s"
    sleep 5
  done
  $KUBECTL_DEV get nodes || fail_phase "get-nodes"
else
  log_info "  WARN: ccs-dev kubeconfig not found -- skipping node check"
fi

# ── Step 4: TalosCluster import on management cluster ─────────────────────────

DEV_CR="${SCRIPT_DIR}/../configs/ccs-dev/compiled/bootstrap/ccs-dev.yaml"
if [ -f "$DEV_CR" ]; then
  log_info "phase-c step=4 Applying ccs-dev TalosCluster CR to management cluster"
  $KUBECTL_MGMT apply --server-side --force-conflicts -f "$DEV_CR" \
    || fail_phase "apply-ccs-dev-taloscluster"
else
  log_info "phase-c step=4 SKIP: ccs-dev TalosCluster CR not found at ${DEV_CR}"
fi

# ── Step 5: AC-2, AC-4 acceptance contracts ───────────────────────────────────

log_info "phase-c step=5 Running AC-2 (wrapper e2e)"
export MGMT_KUBECONFIG
export TENANT_KUBECONFIG="${HOME}/.kube/ccs-dev.yaml"
(cd "${SCRIPT_DIR}/../../wrapper" && make e2e) || fail_phase "ac2-wrapper-e2e"
log_info "  AC-2 PASS"

log_info "phase-c step=6 Running AC-4 (seam-core e2e)"
(cd "${SCRIPT_DIR}/../../seam-core" && make e2e) || fail_phase "ac4-seam-core-e2e"
log_info "  AC-4 PASS"

pass_phase
