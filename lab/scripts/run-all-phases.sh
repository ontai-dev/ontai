#!/usr/bin/env bash
# lab/scripts/run-all-phases.sh -- Master runner for live cluster validation phases.
#
# Runs phases A and B automatically. Phases C-F are destructive or require
# prerequisites and must be invoked manually per the instructions printed below.
#
# Usage:
#   bash run-all-phases.sh
#
# Environment:
#   MGMT_KUBECONFIG  path to ccs-mgmt kubeconfig (default: ~/.kube/ccs-mgmt.yaml)
#   DEV_KUBECONFIG   path to ccs-dev kubeconfig (default: ~/.kube/ccs-dev.yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

MGMT_KUBECONFIG="${MGMT_KUBECONFIG:-${HOME}/.kube/ccs-mgmt.yaml}"
DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/ccs-dev.yaml}"

export MGMT_KUBECONFIG
export DEV_KUBECONFIG

START_TS=$(date +%s)

log_info "run-all-phases: starting automated phases A and B"
log_info "  MGMT_KUBECONFIG=${MGMT_KUBECONFIG}"
log_info "  DEV_KUBECONFIG=${DEV_KUBECONFIG}"

# ── Phase A: management cluster import ────────────────────────────────────────

log_info ""
log_info "==> Phase A: management cluster import"
bash "${SCRIPT_DIR}/phase-a-mgmt-import.sh" || {
  echo "FAIL run-all-phases: Phase A failed. Stopping." >&2
  exit 1
}

# ── Phase B: ccs-dev tenant cluster import ────────────────────────────────────

log_info ""
log_info "==> Phase B: ccs-dev tenant import"
bash "${SCRIPT_DIR}/phase-b-dev-import.sh" || {
  echo "FAIL run-all-phases: Phase B failed. Stopping." >&2
  exit 1
}

# ── Done: print manual phase instructions ────────────────────────────────────

ELAPSED=$(( $(date +%s) - START_TS ))
echo ""
echo "PASS run-all-phases: Phases A and B complete (elapsed=${ELAPSED}s)"
echo ""
echo "Phases C-F require human confirmation or additional prerequisites."
echo "Run each manually:"
echo ""
echo "  Phase C (destructive -- ONT-native bootstrap):"
echo "    CONFIRM_DESTRUCTIVE=yes bash ${SCRIPT_DIR}/phase-c-dev-native-bootstrap.sh"
echo ""
echo "  Phase D (destructive -- CAPI bootstrap):"
echo "    CONFIRM_DESTRUCTIVE=yes bash ${SCRIPT_DIR}/phase-d-dev-capi-bootstrap.sh"
echo ""
echo "  Phase E (Helm ClusterPack -- requires cert-manager pack CR):"
echo "    bash ${SCRIPT_DIR}/phase-e-helm-clusterpack.sh"
echo ""
echo "  Phase F (day-2 ops -- requires Phase A+B or Phase A+D passed):"
echo "    bash ${SCRIPT_DIR}/phase-f-day2-ops.sh"
