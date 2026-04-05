#!/usr/bin/env bash
# lab/scripts/05-bootstrap.sh — bootstrap etcd on the first control plane node,
# wait for cluster health, then retrieve talosconfig and kubeconfig.
#
# Bootstrap is idempotent — if the cluster is already bootstrapped (etcd
# already initialized), talosctl bootstrap returns a non-fatal error which
# the script tolerates.
#
# Outputs written to lab/configs/{cluster-name}/:
#   talosconfig         — Talos client config (must already exist from config gen)
#   {cluster-name}.yaml — Kubernetes API kubeconfig
#
# Lab invariant (lab/CLAUDE.md): talosconfig has endpoints=[] — always pass
#   --endpoints explicitly to every talosctl command.
#
# Usage: 05-bootstrap.sh <cluster-name>
#   cluster-name: ccs-mgmt | ccs-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools talosctl kubectl

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt | ccs-dev)"
[[ "$CLUSTER" == "ccs-mgmt" || "$CLUSTER" == "ccs-dev" ]] \
  || fail_fast "Unknown cluster '${CLUSTER}'. Valid values: ccs-mgmt, ccs-dev"

ONTAI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIGS_DIR="${ONTAI_ROOT}/lab/configs/${CLUSTER}"
TALOSCONFIG="${CONFIGS_DIR}/talosconfig"
KUBECONFIG_OUT="${CONFIGS_DIR}/${CLUSTER}.yaml"

[ -d "$CONFIGS_DIR" ] \
  || fail_fast "Configs directory not found: ${CONFIGS_DIR}"
[ -f "$TALOSCONFIG" ] \
  || fail_fast "talosconfig not found: ${TALOSCONFIG}. Generate machine configs first."

# ── Cluster-specific constants ────────────────────────────────────────────────

if [ "$CLUSTER" = "ccs-mgmt" ]; then
  CP1_IP="10.20.0.2"
  VIP="10.20.0.10"
else  # ccs-dev
  CP1_IP="10.20.0.11"
  VIP="10.20.0.15"
fi

log_info "Cluster:      ${CLUSTER}"
log_info "CP1 IP:       ${CP1_IP}"
log_info "VIP:          ${VIP}"
log_info "talosconfig:  ${TALOSCONFIG}"

# ── Bootstrap etcd ────────────────────────────────────────────────────────────
# Run exactly once per cluster lifetime. Idempotent: talosctl returns an
# error if already bootstrapped — we tolerate it with a warning.

log_info "=== Bootstrapping etcd on ${CP1_IP} ==="

if talosctl bootstrap \
    --nodes     "$CP1_IP" \
    --endpoints "$CP1_IP" \
    --talosconfig "$TALOSCONFIG" 2>&1; then
  log_info "Bootstrap initiated on ${CP1_IP}"
else
  log_info "Bootstrap returned non-zero — cluster may already be bootstrapped. Continuing."
fi

# ── Wait for cluster health ───────────────────────────────────────────────────
# Allow up to 10 minutes for etcd to elect a leader and API server to start.

log_info "=== Waiting for cluster health (may take several minutes) ==="

HEALTH_TIMEOUT=600
HEALTH_INTERVAL=15
elapsed=0
health_ok=false

while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
  if talosctl health \
      --nodes     "$CP1_IP" \
      --endpoints "$CP1_IP" \
      --talosconfig "$TALOSCONFIG" \
      --wait-timeout 30s 2>&1; then
    health_ok=true
    break
  fi
  log_info "  ... cluster not healthy yet (${elapsed}s elapsed) — retrying in ${HEALTH_INTERVAL}s"
  sleep "$HEALTH_INTERVAL"
  elapsed=$(( elapsed + HEALTH_INTERVAL ))
done

$health_ok || fail_fast "Cluster health check timed out after ${HEALTH_TIMEOUT}s"
log_info "Cluster is healthy"

# ── Retrieve kubeconfig ───────────────────────────────────────────────────────

log_info "=== Retrieving kubeconfig ==="

talosctl kubeconfig \
  --nodes       "$CP1_IP" \
  --endpoints   "$CP1_IP" \
  --talosconfig "$TALOSCONFIG" \
  --force-context-name "$CLUSTER" \
  "$KUBECONFIG_OUT"

log_info "kubeconfig written to ${KUBECONFIG_OUT}"

# Verify API server is reachable via VIP
log_info "Verifying Kubernetes API via VIP ${VIP}:6443 ..."
wait_port_open_ipv4 "$VIP" 6443 120 5

log_info "Kubernetes API is reachable at ${VIP}:6443"

# Quick node listing to confirm
log_info "=== Cluster nodes ==="
kubectl get nodes --kubeconfig "$KUBECONFIG_OUT" || true

# ── Done ──────────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Bootstrap complete for ${CLUSTER} ==="
log_info ""
log_info "Run the following to set your shell environment:"
log_info ""
if [ "$CLUSTER" = "ccs-mgmt" ]; then
  echo "  export MGMT_KUBECONFIG=${KUBECONFIG_OUT}"
  echo "  export TALOSCONFIG=${TALOSCONFIG}"
else
  echo "  export TENANT_KUBECONFIG=${KUBECONFIG_OUT}"
  echo "  export TALOSCONFIG=${TALOSCONFIG}"
fi
log_info ""
log_info "Nodes are NotReady (CNI not yet deployed). Next step: run 06-platform-deploy.sh ${CLUSTER}"
