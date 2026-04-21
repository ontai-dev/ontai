#!/usr/bin/env bash
# lab/scripts/phase-a-mgmt-import.sh -- Phase A: management cluster import validation.
#
# Starts ccs-mgmt VMs, waits for the Kubernetes API, applies updated CRDs and
# operator deployments from the compiled enable bundle, applies the TalosCluster
# import CR, then runs AC-1 and AC-3 acceptance contracts.
#
# Usage:
#   bash phase-a-mgmt-import.sh
#
# Environment:
#   MGMT_KUBECONFIG  path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   SKIP_VM_START    set non-empty to skip virsh start (VMs already running)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
ENABLE_DIR="${SCRIPT_DIR}/../configs/ccs-mgmt/compiled/enable"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../configs/ccs-mgmt/compiled/bootstrap"
KUBECTL="kubectl --kubeconfig ${MGMT_KUBECONFIG}"

START_TS=$(date +%s)

fail_phase() {
  local step="$1"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "FAIL [phase-a] step=${step} elapsed=${elapsed}s" >&2
  exit 1
}

pass_phase() {
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "PASS [phase-a] elapsed=${elapsed}s"
}

# ── Step 1: Start ccs-mgmt VMs ────────────────────────────────────────────────

if [ -z "${SKIP_VM_START:-}" ]; then
  log_info "phase-a step=1 Starting ccs-mgmt VMs"
  for vm in ccs-mgmt-cp1 ccs-mgmt-cp2 ccs-mgmt-cp3 ccs-mgmt-w1 ccs-mgmt-w2; do
    state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
    if [ "$state" = "running" ]; then
      log_info "  $vm already running -- skipping"
    else
      log_info "  virsh start $vm"
      virsh start "$vm" || fail_phase "virsh-start-${vm}"
      sleep 5
    fi
  done
else
  log_info "phase-a step=1 SKIP_VM_START set -- skipping virsh start"
fi

# ── Step 2: Wait for Kubernetes API ───────────────────────────────────────────

log_info "phase-a step=2 Waiting for Kubernetes API at ${MGMT_KUBECONFIG} (max 3 min)"
API_OK=0
for i in $(seq 1 36); do
  if $KUBECTL cluster-info --request-timeout=5s >/dev/null 2>&1; then
    API_OK=1
    break
  fi
  log_info "  API not ready yet (attempt ${i}/36) -- sleeping 5s"
  sleep 5
done
[ "$API_OK" = "1" ] || fail_phase "api-wait-timeout"
log_info "  API reachable"

# ── Step 3: Apply seam-core and infrastructure CRDs ──────────────────────────
# SC-INV-003: seam-core CRDs must be installed before all operators.
# This also installs SeamMembership CRD needed by 01-guardian-bootstrap.

log_info "phase-a step=3a Applying 00-infrastructure-dependencies (seam-core CRDs)"
$KUBECTL apply --server-side --force-conflicts \
  -f "${ENABLE_DIR}/00-infrastructure-dependencies/" \
  || fail_phase "apply-00-infrastructure-dependencies"

# ── Step 3b: Wait for guardian webhook to be ready ────────────────────────────
# Guardian admission webhook fires when RBACPolicy/RBACProfile CRs are applied.
# Guardian must be healthy before phase 01 applies those resources.

log_info "phase-a step=3b Waiting for guardian deployment ready (max 2 min)"
guardian_count=$($KUBECTL get deployment guardian -n seam-system --no-headers 2>/dev/null | wc -l)
if [ "$guardian_count" -gt 0 ]; then
  $KUBECTL rollout status deployment/guardian -n seam-system --timeout=120s \
    || fail_phase "guardian-ready-wait"
  log_info "  guardian deployment ready"
else
  log_info "  guardian deployment not found -- skipping wait (first install)"
fi

# ── Step 3c: Apply operator resources ─────────────────────────────────────────

log_info "phase-a step=3c Applying enable bundle phases"
for phase in 01-guardian-bootstrap 03-platform-wrapper 04-conductor; do
  phase_dir="${ENABLE_DIR}/${phase}"
  if [ ! -d "$phase_dir" ]; then
    log_info "  WARN: phase directory not found: ${phase_dir} -- skipping"
    continue
  fi
  log_info "  applying phase=${phase}"
  $KUBECTL apply --server-side --force-conflicts -f "${phase_dir}/" \
    || fail_phase "apply-${phase}"
done

# ── Step 4: Restart operator deployments ──────────────────────────────────────

log_info "phase-a step=4 Restarting operator deployments (pick up new images)"
for ns in seam-system ont-system; do
  count=$($KUBECTL get deployments -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    log_info "  rollout restart deployments in ns=${ns}"
    $KUBECTL rollout restart deployment -n "$ns" || fail_phase "rollout-restart-${ns}"
    $KUBECTL rollout status deployment -n "$ns" --timeout=120s \
      || fail_phase "rollout-status-${ns}"
  else
    log_info "  no deployments in ns=${ns} -- skipping"
  fi
done

# ── Step 5: Ensure talosconfig secret and apply TalosCluster import CR ────────

log_info "phase-a step=5a Ensuring talosconfig Secret in seam-system"
TALOSCONFIG_FILE="${SCRIPT_DIR}/../configs/ccs-mgmt/talosconfig"
[ -f "$TALOSCONFIG_FILE" ] || fail_phase "talosconfig-file-missing-at-${TALOSCONFIG_FILE}"
$KUBECTL create secret generic seam-mc-ccs-mgmt-talosconfig \
  -n seam-system \
  --from-file=talosconfig="${TALOSCONFIG_FILE}" \
  --dry-run=client -o yaml \
  | $KUBECTL apply --server-side -f - \
  || fail_phase "apply-talosconfig-secret"

log_info "phase-a step=5b Applying TalosCluster import CR"
TALOS_CR="${BOOTSTRAP_DIR}/ccs-mgmt.yaml"
[ -f "$TALOS_CR" ] || fail_phase "taloscluster-cr-missing"
$KUBECTL apply --server-side --force-conflicts -f "$TALOS_CR" \
  || fail_phase "apply-taloscluster-cr"

log_info "  waiting for TalosCluster ccs-mgmt Ready (max 2 min)"
for i in $(seq 1 24); do
  ready=$($KUBECTL get taloscluster ccs-mgmt -n seam-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [ "$ready" = "True" ]; then
    log_info "  TalosCluster ccs-mgmt Ready=True"
    break
  fi
  if [ "$i" = "24" ]; then
    log_info "  WARN: TalosCluster not Ready after 2 min -- continuing to acceptance tests"
  fi
  sleep 5
done

# ── Step 6: AC-1 platform acceptance contract ─────────────────────────────────

log_info "phase-a step=6 Running AC-1 (platform e2e)"
export MGMT_KUBECONFIG
(cd "${SCRIPT_DIR}/../../platform" && make e2e) || fail_phase "ac1-platform-e2e"
log_info "  AC-1 PASS"

# ── Step 7: AC-3 guardian audit acceptance contract ───────────────────────────

log_info "phase-a step=7 Running AC-3 (guardian e2e)"
(cd "${SCRIPT_DIR}/../../guardian" && make e2e) || fail_phase "ac3-guardian-e2e"
log_info "  AC-3 PASS"

# ── Done ──────────────────────────────────────────────────────────────────────

pass_phase
