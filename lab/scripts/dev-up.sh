#!/usr/bin/env bash
# lab/scripts/dev-up.sh -- bring up ccs-dev with a configurable MODE.
#
# MODE=import     Start VMs only. No machineconfig push. For clusters that are
#                 already bootstrapped and just need their VMs running.
# MODE=bootstrap  Start VMs and push machineconfigs via talosctl apply-config.
#                 This is the full ONT-native bootstrap path.
# MODE=capi       Start VMs but do not push machineconfigs. CAPI delivers
#                 configs via port 50000 after the TalosCluster CR is applied.
#
# Usage: MODE=import bash dev-up.sh [ccs-dev]
#        MODE=bootstrap bash dev-up.sh [ccs-dev]
#        MODE=capi bash dev-up.sh [ccs-dev]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MODE="${MODE:-import}"
CLUSTER="${1:-ccs-dev}"

[[ "$MODE" == "import" || "$MODE" == "bootstrap" || "$MODE" == "capi" ]] \
  || fail_fast "Unknown MODE='${MODE}'. Valid values: import, bootstrap, capi"

log_info "dev-up: CLUSTER=${CLUSTER} MODE=${MODE}"

# Step 1 -- Ensure VMs exist (create linked clones if absent).
log_info "==> [dev-up] Creating ${CLUSTER} linked clones (idempotent)"
bash "${SCRIPT_DIR}/02-cluster-create.sh" "$CLUSTER"

# Step 2 -- Start VMs and wait for port 50000 (maintenance mode).
log_info "==> [dev-up] Starting ${CLUSTER} VMs"
bash "${SCRIPT_DIR}/03-cluster-start.sh" "$CLUSTER"

# Step 3 -- MODE guard: machineconfig push is skipped for import and capi.
if [ "$MODE" = "import" ]; then
  log_info "Import mode: skipping machineconfig push"
  log_info "VMs are running. The cluster is expected to already be bootstrapped."
  exit 0
fi

if [ "$MODE" = "capi" ]; then
  log_info "CAPI mode: skipping machineconfig push"
  log_info "VMs are in maintenance mode (port 50000). CAPI will deliver machineconfigs."
  exit 0
fi

# MODE=bootstrap: full machineconfig apply and etcd bootstrap.
log_info "==> [dev-up] Applying machine configs to ${CLUSTER}"
bash "${SCRIPT_DIR}/04-machineconfig-apply.sh" "$CLUSTER"

log_info "==> [dev-up] Bootstrapping ${CLUSTER}"
bash "${SCRIPT_DIR}/05-bootstrap.sh" "$CLUSTER"

log_info "dev-up complete: CLUSTER=${CLUSTER} MODE=${MODE}"
