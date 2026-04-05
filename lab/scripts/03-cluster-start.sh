#!/usr/bin/env bash
# lab/scripts/03-cluster-start.sh — start all VMs for a cluster and wait for
# Talos maintenance mode (port 50000) on each node's pre-computed IPv6
# link-local address.
#
# IPv6 addresses are hard-coded from the deterministic table — never derived
# at runtime. Cluster-specific tables below.
#
# Usage: 03-cluster-start.sh <cluster-name>
#   cluster-name: ccs-mgmt | ccs-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools virsh nc

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt | ccs-dev)"
[[ "$CLUSTER" == "ccs-mgmt" || "$CLUSTER" == "ccs-dev" ]] \
  || fail_fast "Unknown cluster '${CLUSTER}'. Valid values: ccs-mgmt, ccs-dev"

IFACE="talos-br0"

# ── Cluster node tables (hard-coded) ─────────────────────────────────────────
# All values from lab/CLAUDE.md deterministic MAC table.
# IPv6 link-local: EUI-64 from MAC, pre-computed — never derived at runtime.

if [ "$CLUSTER" = "ccs-mgmt" ]; then
  NODES=(ccs-mgmt-cp1 ccs-mgmt-cp2 ccs-mgmt-cp3 ccs-mgmt-w1 ccs-mgmt-w2)

  # Pre-computed EUI-64 link-local addresses for ccs-mgmt (cluster byte 01).
  # MAC 52:54:00:01:0A:NN → 50:54:00:ff:fe:01:0A:NN → fe80::5054:ff:fe01:aNn
  declare -A NODE_IPV6=(
    [ccs-mgmt-cp1]="fe80::5054:ff:fe01:a01"
    [ccs-mgmt-cp2]="fe80::5054:ff:fe01:a02"
    [ccs-mgmt-cp3]="fe80::5054:ff:fe01:a03"
    [ccs-mgmt-w1]="fe80::5054:ff:fe01:b01"
    [ccs-mgmt-w2]="fe80::5054:ff:fe01:b02"
  )

else  # ccs-dev — cluster byte 02
  NODES=(ccs-dev-cp1 ccs-dev-cp2 ccs-dev-cp3 ccs-dev-w1 ccs-dev-w2)

  # Pre-computed EUI-64 link-local addresses for ccs-dev (cluster byte 02).
  # MAC 52:54:00:02:0A:NN → 50:54:00:ff:fe:02:0A:NN → fe80::5054:ff:fe02:aNn
  declare -A NODE_IPV6=(
    [ccs-dev-cp1]="fe80::5054:ff:fe02:a01"
    [ccs-dev-cp2]="fe80::5054:ff:fe02:a02"
    [ccs-dev-cp3]="fe80::5054:ff:fe02:a03"
    [ccs-dev-w1]="fe80::5054:ff:fe02:b01"
    [ccs-dev-w2]="fe80::5054:ff:fe02:b02"
  )
fi

# ── Preflight: verify all domains are defined ─────────────────────────────────

for node in "${NODES[@]}"; do
  vm_is_defined "$node" \
    || fail_fast "Domain ${node} not defined. Run 02-cluster-create.sh ${CLUSTER} first."
done

# ── Start VMs ────────────────────────────────────────────────────────────────

log_info "=== Starting ${CLUSTER} VMs ==="

for node in "${NODES[@]}"; do
  state="$(vm_state "$node")"
  if [ "$state" = "running" ]; then
    log_info "${node} is already running"
  else
    log_info "Starting ${node} (current state: ${state})"
    virsh start "$node"
  fi
done

# ── Wait for port 50000 on each node's IPv6 link-local ───────────────────────
# Nodes boot from linked clone (golden rootfs on disk) directly into Talos
# maintenance mode — no ISO install cycle. Typical boot: 30-60 seconds.

log_info "=== Waiting for Talos maintenance mode (port 50000) on all nodes ==="

declare -A node_status=()

for node in "${NODES[@]}"; do
  ipv6="${NODE_IPV6[$node]}%${IFACE}"
  if wait_port_open "$ipv6" 50000 300 5; then
    node_status["$node"]="OK"
  else
    node_status["$node"]="TIMEOUT"
  fi
done

# ── Status report ─────────────────────────────────────────────────────────────

log_info ""
log_info "=== ${CLUSTER} node reachability ==="
all_ok=true
for node in "${NODES[@]}"; do
  ipv6="${NODE_IPV6[$node]}"
  status="${node_status[$node]}"
  if [ "$status" = "OK" ]; then
    log_info "  OK      ${node}  ${ipv6}%${IFACE}:50000"
  else
    log_error "  TIMEOUT ${node}  ${ipv6}%${IFACE}:50000"
    all_ok=false
  fi
done

if $all_ok; then
  log_info ""
  log_info "All ${CLUSTER} nodes are in Talos maintenance mode."
  log_info "Next step: run 04-machineconfig-apply.sh ${CLUSTER}"
else
  log_error ""
  log_error "Some nodes did not reach port 50000. Check:"
  log_error "  1. VM console: virsh console <node-name>"
  log_error "  2. GRUB stuck: the human may need to run 'virsh send-key <name> KEY_ENTER'"
  exit 1
fi
