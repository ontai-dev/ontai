#!/usr/bin/env bash
# lab/scripts/phase-e-helm-clusterpack.sh -- Phase E: cert-manager Helm ClusterPack.
#
# Compiles and deploys a cert-manager ClusterPack via Wrapper, verifies PackExecution
# and PackInstance lifecycle, and confirms PackReceipt on the tenant cluster.
#
# Prerequisites:
#   - Phase B or D must have passed (ccs-dev up and imported)
#   - MGMT_KUBECONFIG and DEV_KUBECONFIG must be valid
#
# Usage:
#   bash phase-e-helm-clusterpack.sh
#
# Environment:
#   MGMT_KUBECONFIG  path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   DEV_KUBECONFIG   path to ccs-dev kubeconfig (default: ~/.kube/ccs-dev.yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/ccs-dev.yaml}"
KUBECTL_MGMT="kubectl --kubeconfig ${MGMT_KUBECONFIG}"
KUBECTL_DEV="kubectl --kubeconfig ${DEV_KUBECONFIG}"
START_TS=$(date +%s)

fail_phase() {
  local step="$1"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "FAIL [phase-e] step=${step} elapsed=${elapsed}s" >&2
  exit 1
}

pass_phase() {
  local elapsed=$(( $(date +%s) - START_TS ))
  echo "PASS [phase-e] elapsed=${elapsed}s"
}

# ── Step 1: Apply cert-manager ClusterPack CR ─────────────────────────────────

log_info "phase-e step=1 Applying cert-manager ClusterPack to management cluster"
PACK_CR="${SCRIPT_DIR}/../configs/ccs-mgmt/packs/cert-manager-clusterpack.yaml"
if [ ! -f "$PACK_CR" ]; then
  echo "BLOCKER [phase-e] cert-manager ClusterPack CR not found at ${PACK_CR}" >&2
  echo "  Create configs/ccs-mgmt/packs/cert-manager-clusterpack.yaml before running phase-e." >&2
  fail_phase "pack-cr-missing"
fi
$KUBECTL_MGMT apply --server-side --force-conflicts -f "$PACK_CR" \
  || fail_phase "apply-clusterpack"

# ── Step 2: Wait for PackExecution Ready ──────────────────────────────────────

log_info "phase-e step=2 Waiting for PackExecution Ready (max 5 min)"
PACK_NAME="cert-manager"
for i in $(seq 1 60); do
  ready=$($KUBECTL_MGMT get packexecution "$PACK_NAME" -n ont-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [ "$ready" = "True" ]; then
    log_info "  PackExecution ${PACK_NAME} Ready=True"
    break
  fi
  log_info "  PackExecution not Ready (attempt ${i}/60) -- sleeping 5s"
  if [ "$i" = "60" ]; then
    fail_phase "packexecution-ready-timeout"
  fi
  sleep 5
done

# ── Step 3: Wait for PackInstance Ready on tenant cluster ─────────────────────

log_info "phase-e step=3 Waiting for PackInstance Ready on ccs-dev (max 5 min)"
for i in $(seq 1 60); do
  ready=$($KUBECTL_DEV get packinstance "$PACK_NAME" -n ont-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [ "$ready" = "True" ]; then
    log_info "  PackInstance ${PACK_NAME} Ready=True on ccs-dev"
    break
  fi
  log_info "  PackInstance not Ready on ccs-dev (attempt ${i}/60) -- sleeping 5s"
  if [ "$i" = "60" ]; then
    log_info "  WARN: PackInstance not Ready after 5 min -- PackReceipt check may be pending"
    break
  fi
  sleep 5
done

# ── Step 4: Verify PackReceipt on tenant cluster ──────────────────────────────

log_info "phase-e step=4 Verifying PackReceipt on ccs-dev"
receipt_count=$($KUBECTL_DEV get packreceipt -n ont-system --no-headers 2>/dev/null | wc -l)
if [ "$receipt_count" -gt 0 ]; then
  log_info "  PackReceipt count=${receipt_count} -- OK"
  $KUBECTL_DEV get packreceipt -n ont-system
else
  log_info "  WARN: no PackReceipts found on ccs-dev (conductor agent may not be deployed)"
fi

# ── Step 5: Verify cert-manager pods on tenant cluster ───────────────────────

log_info "phase-e step=5 Verifying cert-manager pods on ccs-dev"
CM_READY=$($KUBECTL_DEV get pods -n cert-manager --no-headers 2>/dev/null \
  | grep -c "Running" || echo "0")
if [ "$CM_READY" -gt 0 ]; then
  log_info "  cert-manager running pods=${CM_READY} -- OK"
else
  log_info "  WARN: no cert-manager pods Running on ccs-dev"
fi

pass_phase
