#!/usr/bin/env bash
# lab/scripts/06-platform-deploy.sh — deploy Cilium and Kueue onto a cluster.
#
# Deploys from the local Helm chart server and OCI registry — no internet access.
# All image references point to 10.20.0.1:5000 (pre-pushed images required).
#
# Cilium deployment (lab/CLAUDE.md §Cilium Deployment Invariants):
#   - Two-phase install: helm install then helm upgrade (required by Cilium)
#   - native routing, BPF masquerade, L2 announcements, MTU 1450
#   - kube-proxy replacement: strict (kube-proxy disabled at Talos level)
#
# Kueue deployment (lab/CLAUDE.md §Kueue Version Invariant):
#   - Uses pre-substituted manifest: lab/configs/charts/kueue-v0.16.2.yaml
#   - All image refs already point to 10.20.0.1:5000 in the manifest
#
# Currently supports ccs-mgmt only (first cluster to receive platform stack).
#
# Usage: 06-platform-deploy.sh <cluster-name>
#   cluster-name: ccs-mgmt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools helm kubectl

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt)"
[ "$CLUSTER" = "ccs-mgmt" ] \
  || fail_fast "06-platform-deploy.sh currently supports ccs-mgmt only. Got: ${CLUSTER}"

ONTAI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIGS_DIR="${ONTAI_ROOT}/lab/configs/${CLUSTER}"
KUBECONFIG="${CONFIGS_DIR}/${CLUSTER}.yaml"
KUEUE_MANIFEST="${ONTAI_ROOT}/lab/configs/charts/kueue-v0.16.2.yaml"

[ -f "$KUBECONFIG" ] \
  || fail_fast "kubeconfig not found: ${KUBECONFIG}. Run 05-bootstrap.sh ${CLUSTER} first."
[ -f "$KUEUE_MANIFEST" ] \
  || fail_fast "Kueue manifest not found: ${KUEUE_MANIFEST}"

REGISTRY="10.20.0.1:5000"
HELM_REPO_URL="http://10.20.0.1:8888"
HELM_REPO_NAME="local-charts"

# ── Add local Helm repo ───────────────────────────────────────────────────────

log_info "=== Configuring local Helm chart repository ==="

if helm repo list 2>/dev/null | grep -q "^${HELM_REPO_NAME}"; then
  log_info "Helm repo '${HELM_REPO_NAME}' already configured — updating"
  helm repo update "$HELM_REPO_NAME"
else
  log_info "Adding Helm repo '${HELM_REPO_NAME}' → ${HELM_REPO_URL}"
  helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
  helm repo update "$HELM_REPO_NAME"
fi

# ── Deploy Cilium — Phase 1: initial install ──────────────────────────────────
# Phase 1 installs Cilium with minimal settings to bootstrap the CNI.
# Phase 2 upgrades with the full production config.
# This two-phase sequence is required by Cilium. lab/CLAUDE.md §Cilium Invariants.

log_info "=== Deploying Cilium — Phase 1 (initial install) ==="

CILIUM_COMMON_VALUES=(
  --set "image.repository=${REGISTRY}/cilium/cilium"
  --set "image.pullPolicy=IfNotPresent"
  --set "operator.image.repository=${REGISTRY}/cilium/operator"
  --set "operator.image.pullPolicy=IfNotPresent"
  --set "operator.replicas=1"
  --set "kubeProxyReplacement=strict"
  --set "routingMode=native"
  --set "autoDirectNodeRoutes=true"
  --set "ipv4NativeRoutingCIDR=10.0.0.0/8"
  --set "bpf.masquerade=true"
  --set "l2announcements.enabled=true"
  --set "MTU=1450"
  --set "k8sServiceHost=${REGISTRY%:*}"
  --set "k8sServicePort=6443"
)

if helm status cilium -n kube-system --kubeconfig "$KUBECONFIG" &>/dev/null; then
  log_info "Cilium already installed — skipping Phase 1"
else
  helm install cilium "${HELM_REPO_NAME}/cilium" \
    --namespace kube-system \
    --kubeconfig "$KUBECONFIG" \
    --wait \
    --timeout 5m \
    "${CILIUM_COMMON_VALUES[@]}"
  log_info "Cilium Phase 1 install complete"
fi

# ── Deploy Cilium — Phase 2: upgrade with full config ────────────────────────

log_info "=== Deploying Cilium — Phase 2 (upgrade with full config) ==="

helm upgrade cilium "${HELM_REPO_NAME}/cilium" \
  --namespace kube-system \
  --kubeconfig "$KUBECONFIG" \
  --wait \
  --timeout 5m \
  "${CILIUM_COMMON_VALUES[@]}"

log_info "Cilium Phase 2 upgrade complete"

# ── Wait for Cilium pods ──────────────────────────────────────────────────────

log_info "=== Waiting for Cilium pods to be Ready ==="

kubectl rollout status daemonset/cilium \
  -n kube-system \
  --kubeconfig "$KUBECONFIG" \
  --timeout=300s

kubectl rollout status deployment/cilium-operator \
  -n kube-system \
  --kubeconfig "$KUBECONFIG" \
  --timeout=300s

log_info "Cilium is Ready"

# ── Deploy Kueue ──────────────────────────────────────────────────────────────
# kueue-v0.16.2.yaml has all image refs pre-substituted to 10.20.0.1:5000.
# lab/CLAUDE.md §Kueue Version Invariant.

log_info "=== Deploying Kueue from ${KUEUE_MANIFEST} ==="

kubectl apply -f "$KUEUE_MANIFEST" --kubeconfig "$KUBECONFIG"

# ── Wait for Kueue pods ───────────────────────────────────────────────────────

log_info "=== Waiting for Kueue controller-manager to be Ready ==="

kubectl rollout status deployment/kueue-controller-manager \
  -n kueue-system \
  --kubeconfig "$KUBECONFIG" \
  --timeout=300s

log_info "Kueue is Ready"

# ── Verify nodes are Ready ────────────────────────────────────────────────────

log_info "=== Cluster node status ==="
kubectl get nodes --kubeconfig "$KUBECONFIG"

# ── Done ──────────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Platform deploy complete for ${CLUSTER} ==="
log_info "  Cilium:  deployed (two-phase), native routing, BPF masquerade, L2 announcements"
log_info "  Kueue:   deployed from ${KUEUE_MANIFEST}"
log_info ""
log_info "Run 'make e2e' once MGMT_KUBECONFIG and TENANT_KUBECONFIG are both set."
