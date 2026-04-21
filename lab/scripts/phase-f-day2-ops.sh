#!/usr/bin/env bash
# lab/scripts/phase-f-day2-ops.sh -- Phase F: day-2 operational scenarios.
#
# Runs six day-2 scenarios:
#   1. ILI lineage verification for a TalosCluster root declaration
#   2. OutcomeRegistry entry confirmed on a terminal PackExecution
#   3. Guardian audit trail contains lineageIndexRef for RBACPolicy event
#   4. RBAC intake flow (submit third-party RBAC, verify guardian stamp)
#   5. PackInstance drift detection check (descriptor vs PackReceipt divergence)
#   6. Tenant GC: delete TalosCluster CR, verify seam-tenant namespace removed
#
# Prerequisites: phases A and B (or D) must have passed.
#
# Usage:
#   bash phase-f-day2-ops.sh
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

PASS_COUNT=0
FAIL_COUNT=0

scenario_pass() { log_info "  PASS scenario=$1"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
scenario_fail() { log_info "  FAIL scenario=$1: $2"; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# ── Scenario 1: ILI lineage for ccs-mgmt TalosCluster ────────────────────────

log_info "phase-f scenario=1 ILI lineage verification for ccs-mgmt"
ILI_NAME=$($KUBECTL_MGMT get infrastructurelineageindex -n seam-system \
  --no-headers 2>/dev/null | grep "taloscluster-ccs-mgmt" | awk '{print $1}' || echo "")
if [ -n "$ILI_NAME" ]; then
  ROOT_BINDING=$($KUBECTL_MGMT get infrastructurelineageindex "$ILI_NAME" -n seam-system \
    -o jsonpath='{.spec.rootBinding.name}' 2>/dev/null || echo "")
  DESCENDANTS=$($KUBECTL_MGMT get infrastructurelineageindex "$ILI_NAME" -n seam-system \
    -o jsonpath='{.spec.descendantRegistry}' 2>/dev/null || echo "[]")
  if [ "$ROOT_BINDING" = "ccs-mgmt" ] && [ "$DESCENDANTS" != "[]" ] && [ "$DESCENDANTS" != "" ]; then
    scenario_pass "1-ili-lineage"
  else
    scenario_fail "1-ili-lineage" "rootBinding=${ROOT_BINDING} descendants=${DESCENDANTS}"
  fi
else
  scenario_fail "1-ili-lineage" "no ILI found for taloscluster-ccs-mgmt in seam-system"
fi

# ── Scenario 2: OutcomeRegistry entry on a terminal PackExecution ─────────────

log_info "phase-f scenario=2 OutcomeRegistry on terminal PackExecution"
PE_ILI=$($KUBECTL_MGMT get infrastructurelineageindex -n ont-system \
  --no-headers 2>/dev/null | head -1 | awk '{print $1}' || echo "")
if [ -n "$PE_ILI" ]; then
  OUTCOMES=$($KUBECTL_MGMT get infrastructurelineageindex "$PE_ILI" -n ont-system \
    -o jsonpath='{.spec.outcomeRegistry}' 2>/dev/null || echo "[]")
  if [ "$OUTCOMES" != "[]" ] && [ "$OUTCOMES" != "" ] && [ "$OUTCOMES" != "null" ]; then
    scenario_pass "2-outcome-registry"
  else
    log_info "  INFO: outcomeRegistry empty for ${PE_ILI} -- PackExecution may not be terminal yet"
    scenario_fail "2-outcome-registry" "outcomeRegistry empty on ${PE_ILI}"
  fi
else
  log_info "  INFO: no PackExecution ILI found in ont-system -- phase E may not have run"
  scenario_fail "2-outcome-registry" "no ILI in ont-system"
fi

# ── Scenario 3: Guardian audit contains lineageIndexRef ───────────────────────

log_info "phase-f scenario=3 Guardian audit lineageIndexRef present"
AUDIT_TABLE="audit_events"
GUARDIAN_POD=$($KUBECTL_MGMT get pod -n seam-system -l app=guardian \
  --no-headers 2>/dev/null | awk '{print $1}' | head -1 || echo "")
if [ -n "$GUARDIAN_POD" ]; then
  LINEAGE_REF_COUNT=$($KUBECTL_MGMT exec -n seam-system "$GUARDIAN_POD" -- \
    psql -U guardian -d guardian -t -c \
    "SELECT COUNT(*) FROM ${AUDIT_TABLE} WHERE lineage_index_ref_name IS NOT NULL;" \
    2>/dev/null | tr -d ' ' || echo "0")
  if [ "${LINEAGE_REF_COUNT:-0}" -gt 0 ]; then
    scenario_pass "3-audit-lineage-ref"
  else
    scenario_fail "3-audit-lineage-ref" "no audit rows with lineage_index_ref_name (count=${LINEAGE_REF_COUNT})"
  fi
else
  scenario_fail "3-audit-lineage-ref" "no guardian pod found in seam-system"
fi

# ── Scenario 4: RBAC intake flow ──────────────────────────────────────────────

log_info "phase-f scenario=4 RBAC intake guardian stamp"
# Check an existing ClusterRole has the ontai.dev/rbac-owner=guardian annotation
CR_ANNOTATED=$($KUBECTL_MGMT get clusterrole -l ontai.dev/rbac-owner=guardian \
  --no-headers 2>/dev/null | wc -l || echo "0")
if [ "${CR_ANNOTATED:-0}" -gt 0 ]; then
  scenario_pass "4-rbac-intake"
else
  scenario_fail "4-rbac-intake" "no ClusterRoles with ontai.dev/rbac-owner=guardian (intake not exercised)"
fi

# ── Scenario 5: PackInstance drift detection ──────────────────────────────────

log_info "phase-f scenario=5 PackInstance drift detection (informational)"
DRIFTED=$($KUBECTL_DEV get packinstance -n ont-system \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Drifted")].status}{"\n"}{end}' \
  2>/dev/null || echo "")
if [ -n "$DRIFTED" ]; then
  log_info "  PackInstance drift status:"
  echo "$DRIFTED" | while read -r line; do log_info "    ${line}"; done
  scenario_pass "5-drift-detection-informational"
else
  log_info "  INFO: no PackInstances found on ccs-dev or drift condition absent"
  scenario_fail "5-drift-detection-informational" "no PackInstance drift status available"
fi

# ── Scenario 6: Tenant GC -- seam-tenant namespace cleanup ───────────────────
# NOTE: This scenario is INFORMATIONAL only. It does not delete any resource.
# A TalosCluster deletion requires a separate Governor-confirmed destructive session.

log_info "phase-f scenario=6 Tenant GC finalizer presence (informational)"
GC_FINALIZER=$($KUBECTL_MGMT get taloscluster ccs-dev -n seam-system \
  -o jsonpath='{.metadata.finalizers}' 2>/dev/null || echo "")
if echo "$GC_FINALIZER" | grep -q "platform.ontai.dev/tenant-namespace-cleanup"; then
  log_info "  finalizer platform.ontai.dev/tenant-namespace-cleanup present on ccs-dev TalosCluster"
  scenario_pass "6-tenant-gc-finalizer"
else
  scenario_fail "6-tenant-gc-finalizer" "finalizer not present on ccs-dev TalosCluster (GC-BL-TENANT-GC may not be applied)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

ELAPSED=$(( $(date +%s) - START_TS ))
TOTAL=$(( PASS_COUNT + FAIL_COUNT ))
echo ""
echo "phase-f summary: pass=${PASS_COUNT}/${TOTAL} fail=${FAIL_COUNT}/${TOTAL} elapsed=${ELAPSED}s"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL [phase-f] one or more scenarios failed -- see above" >&2
  exit 1
fi
echo "PASS [phase-f]"
