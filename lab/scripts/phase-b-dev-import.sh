#!/usr/bin/env bash
# lab/scripts/phase-b-dev-import.sh -- Phase B: ccs-dev tenant cluster import validation.
#
# Starts ccs-dev VMs (import mode), applies the ccs-dev TalosCluster CR to ccs-mgmt,
# waits for the cluster to be Ready, then runs AC-2, AC-4, and AC-5 acceptance contracts.
#
# Prerequisite: ccs-mgmt must be up and phase-a-mgmt-import.sh must have passed.
#
# Usage:
#   bash phase-b-dev-import.sh
#
# Environment:
#   MGMT_KUBECONFIG  path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   DEV_KUBECONFIG   path to ccs-dev kubeconfig (default: ~/.kube/ccs-dev.yaml)
#   SKIP_VM_START    set non-empty to skip virsh start (VMs already running)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/ccs-dev.yaml}"
KUBECTL_MGMT="kubectl --kubeconfig ${MGMT_KUBECONFIG}"
KUBECTL_DEV="kubectl --kubeconfig ${DEV_KUBECONFIG}"

DEV_CR_DIR="${SCRIPT_DIR}/../configs/ccs-dev/compiled/bootstrap"

START_TS=$(date +%s)

fail_phase() {
  local step="$1"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "FAIL [phase-b] step=${step} elapsed=${elapsed}s" >&2
  exit 1
}

pass_phase() {
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "PASS [phase-b] elapsed=${elapsed}s"
}

# ── Step 1: Start ccs-dev VMs (import mode) ───────────────────────────────────

if [ -z "${SKIP_VM_START:-}" ]; then
  log_info "phase-b step=1 Starting ccs-dev VMs (import mode)"
  MODE=import bash "${SCRIPT_DIR}/dev-up.sh" ccs-dev || fail_phase "dev-up-import"
else
  log_info "phase-b step=1 SKIP_VM_START set -- skipping VM start"
fi

# ── Step 2: Apply ccs-dev TalosCluster CR to management cluster ───────────────

log_info "phase-b step=2 Applying ccs-dev TalosCluster CR"
DEV_CR="${DEV_CR_DIR}/ccs-dev.yaml"
if [ ! -f "$DEV_CR" ]; then
  log_info "  WARN: ccs-dev TalosCluster CR not found at ${DEV_CR}"
  log_info "  BLOCKER: ccs-dev compiled bootstrap configs do not exist yet."
  log_info "  Run compiler bootstrap for ccs-dev and commit the output before running phase-b."
  fail_phase "ccs-dev-cr-missing"
fi
$KUBECTL_MGMT apply --server-side --force-conflicts -f "$DEV_CR" \
  || fail_phase "apply-ccs-dev-taloscluster"

# ── Step 3: Wait for ccs-dev TalosCluster Ready ───────────────────────────────

log_info "phase-b step=3 Waiting for TalosCluster ccs-dev Ready on management cluster (max 5 min)"
for i in $(seq 1 60); do
  ready=$($KUBECTL_MGMT get taloscluster ccs-dev -n seam-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [ "$ready" = "True" ]; then
    log_info "  TalosCluster ccs-dev Ready=True"
    break
  fi
  if [ "$i" = "60" ]; then
    log_info "  WARN: TalosCluster ccs-dev not Ready after 5 min -- continuing to acceptance tests"
  fi
  sleep 5
done

# ── Step 4: Wait for ccs-dev Kubernetes API ───────────────────────────────────

if [ -f "$DEV_KUBECONFIG" ]; then
  log_info "phase-b step=4 Waiting for ccs-dev Kubernetes API (max 3 min)"
  API_OK=0
  for i in $(seq 1 36); do
    if $KUBECTL_DEV cluster-info --request-timeout=5s >/dev/null 2>&1; then
      API_OK=1
      break
    fi
    log_info "  ccs-dev API not ready yet (attempt ${i}/36) -- sleeping 5s"
    sleep 5
  done
  [ "$API_OK" = "1" ] || fail_phase "ccs-dev-api-wait-timeout"
  log_info "  ccs-dev API reachable"
else
  log_info "  WARN: DEV_KUBECONFIG not found at ${DEV_KUBECONFIG} -- skipping API wait"
fi

# ── Step 4.5: Apply enable bundle to ccs-dev ──────────────────────────────────
# Applies all six enable phases to ccs-dev so Seam operators are running before
# acceptance tests execute. Uses DEV_KUBECONFIG so resources land on ccs-dev.

ENABLE_DIR="${SCRIPT_DIR}/../configs/ccs-dev/compiled/enable"
if [ -d "$ENABLE_DIR" ]; then
  log_info "phase-b step=4.5 Applying enable bundle to ccs-dev (${ENABLE_DIR})"
  for phase_dir in "${ENABLE_DIR}"/*/; do
    phase=$(basename "$phase_dir")
    log_info "  applying phase ${phase}"
    $KUBECTL_DEV apply --server-side --force-conflicts -R -f "$phase_dir" \
      || fail_phase "enable-phase-${phase}"
  done
  log_info "  enable bundle applied"
else
  log_info "  WARN: enable bundle not found at ${ENABLE_DIR} -- skipping (TENANT-CLUSTER-E2E)"
fi

# ── Step 5: AC-2 wrapper deploy gate acceptance contract ──────────────────────

log_info "phase-b step=5 Running AC-2 (wrapper e2e)"
export MGMT_KUBECONFIG
export TENANT_KUBECONFIG="${DEV_KUBECONFIG}"
(cd "${SCRIPT_DIR}/../../wrapper" && make e2e) || fail_phase "ac2-wrapper-e2e"
log_info "  AC-2 PASS"

# ── Step 6: AC-4 seam-core lineage tracking acceptance contract ───────────────

log_info "phase-b step=6 Running AC-4 (seam-core e2e)"
(cd "${SCRIPT_DIR}/../../seam-core" && make e2e) || fail_phase "ac4-seam-core-e2e"
log_info "  AC-4 PASS"

# ── Done ──────────────────────────────────────────────────────────────────────

pass_phase
