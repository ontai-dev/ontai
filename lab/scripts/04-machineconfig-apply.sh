#!/usr/bin/env bash
# lab/scripts/04-machineconfig-apply.sh — apply per-node Talos machine configs
# via talosctl apply-config --insecure.
#
# Apply method: IPv6 link-local with %25 zone encoding (required on fresh boot
# before static IPv4 is configured). Falls back to a Python TCP tunnel if
# talosctl cannot handle %25-encoded zone IDs.
#
# Machine config files must exist at:
#   lab/configs/{cluster-name}/{node-name}.yaml
# e.g. lab/configs/ccs-mgmt/ccs-mgmt-cp1.yaml
#
# After apply, waits for each node to reboot and become reachable on IPv4.
#
# Lab invariant (lab/CLAUDE.md): Port 50000 is gRPC only. Never use curl.
# Lab invariant: First apply uses IPv6 link-local — IPv4 not available until
#   machine config is applied and node reboots.
#
# Usage: 04-machineconfig-apply.sh <cluster-name>
#   cluster-name: ccs-mgmt | ccs-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools talosctl python3 nc

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt | ccs-dev)"
[[ "$CLUSTER" == "ccs-mgmt" || "$CLUSTER" == "ccs-dev" ]] \
  || fail_fast "Unknown cluster '${CLUSTER}'. Valid values: ccs-mgmt, ccs-dev"

# Lab configs directory (relative to ontai root, resolved at runtime)
ONTAI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIGS_DIR="${ONTAI_ROOT}/lab/configs/${CLUSTER}"
IFACE="talos-br0"

[ -d "$CONFIGS_DIR" ] \
  || fail_fast "Configs directory not found: ${CONFIGS_DIR}. Generate machine configs first."

# ── Cluster node tables (hard-coded) ─────────────────────────────────────────

if [ "$CLUSTER" = "ccs-mgmt" ]; then
  NODES=(ccs-mgmt-cp1 ccs-mgmt-cp2 ccs-mgmt-cp3 ccs-mgmt-w1 ccs-mgmt-w2)

  declare -A NODE_IPV4=(
    [ccs-mgmt-cp1]="10.20.0.2"
    [ccs-mgmt-cp2]="10.20.0.3"
    [ccs-mgmt-cp3]="10.20.0.4"
    [ccs-mgmt-w1]="10.20.0.5"
    [ccs-mgmt-w2]="10.20.0.6"
  )
  # Pre-computed EUI-64 IPv6 link-local addresses — never derived at runtime
  declare -A NODE_IPV6=(
    [ccs-mgmt-cp1]="fe80::5054:ff:fe01:a01"
    [ccs-mgmt-cp2]="fe80::5054:ff:fe01:a02"
    [ccs-mgmt-cp3]="fe80::5054:ff:fe01:a03"
    [ccs-mgmt-w1]="fe80::5054:ff:fe01:b01"
    [ccs-mgmt-w2]="fe80::5054:ff:fe01:b02"
  )

else  # ccs-dev
  NODES=(ccs-dev-cp1 ccs-dev-cp2 ccs-dev-cp3 ccs-dev-w1 ccs-dev-w2)

  declare -A NODE_IPV4=(
    [ccs-dev-cp1]="10.20.0.11"
    [ccs-dev-cp2]="10.20.0.12"
    [ccs-dev-cp3]="10.20.0.13"
    [ccs-dev-w1]="10.20.0.14"
    [ccs-dev-w2]="10.20.0.15"
  )
  declare -A NODE_IPV6=(
    [ccs-dev-cp1]="fe80::5054:ff:fe02:a01"
    [ccs-dev-cp2]="fe80::5054:ff:fe02:a02"
    [ccs-dev-cp3]="fe80::5054:ff:fe02:a03"
    [ccs-dev-w1]="fe80::5054:ff:fe02:b01"
    [ccs-dev-w2]="fe80::5054:ff:fe02:b02"
  )
fi

# ── Python TCP tunnel helper (inline — no external dependency) ────────────────
# Used as fallback when talosctl %25 zone encoding fails.
# Spawns a short-lived python3 tunnel: 127.0.0.1:LOCAL_PORT → [ipv6%iface]:50000
# Prints the PID so the caller can kill it after use.

start_tunnel() {
  local local_port="$1"
  local ipv6="$2"
  local iface="$3"

  python3 - "$local_port" "$ipv6" "$iface" <<'PYEOF' &
import socket, threading, sys

local_port = int(sys.argv[1])
ipv6_addr  = sys.argv[2]
iface      = sys.argv[3]
remote_port = 50000

def copy_data(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass

def handle_client(client_sock):
    try:
        scope_id = socket.if_nametoindex(iface)
        remote = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        remote.settimeout(10)
        remote.connect((ipv6_addr, remote_port, 0, scope_id))
        remote.settimeout(None)
        t = threading.Thread(
            target=copy_data, args=(remote, client_sock), daemon=True
        )
        t.start()
        copy_data(client_sock, remote)
        t.join(timeout=5)
    except Exception as e:
        sys.stderr.write(f"tunnel: {e}\n")
    finally:
        client_sock.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('127.0.0.1', local_port))
server.listen(5)
sys.stdout.write(f"tunnel ready on 127.0.0.1:{local_port}\n")
sys.stdout.flush()
while True:
    try:
        conn, _ = server.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
    except OSError:
        break
PYEOF
  echo $!
}

# ── Apply machine configs ─────────────────────────────────────────────────────

log_info "=== Applying machine configs to ${CLUSTER} nodes ==="

declare -A apply_results=()
tunnel_pids=()

# Tunnel base port: each node gets 50100+index to avoid conflicts
TUNNEL_BASE=50100
idx=0

for node in "${NODES[@]}"; do
  ipv4="${NODE_IPV4[$node]}"
  ipv6="${NODE_IPV6[$node]}"
  config_file="${CONFIGS_DIR}/${node}.yaml"
  tunnel_port=$(( TUNNEL_BASE + idx ))
  idx=$(( idx + 1 ))

  [ -f "$config_file" ] \
    || fail_fast "Machine config not found: ${config_file}"

  log_info ""
  log_info "Applying config to ${node} (${ipv6}%${IFACE})"

  # Primary: talosctl with %25-encoded zone ID (RFC 6874 / talosctl convention)
  ipv6_endpoint="[${ipv6}%25${IFACE}]"

  if talosctl apply-config --insecure \
      --nodes   "$ipv6_endpoint" \
      --endpoints "$ipv6_endpoint" \
      --file    "$config_file" 2>&1; then
    log_info "${node}: applied via IPv6 link-local (%25 encoding)"
    apply_results["$node"]="OK-ipv6"
    continue
  fi

  log_info "${node}: %25 encoding failed — starting Python TCP tunnel on 127.0.0.1:${tunnel_port}"

  tunnel_pid="$(start_tunnel "$tunnel_port" "$ipv6" "$IFACE")"
  tunnel_pids+=("$tunnel_pid")

  # Brief pause for tunnel to be ready
  sleep 1

  if talosctl apply-config --insecure \
      --nodes    "127.0.0.1" \
      --endpoints "127.0.0.1:${tunnel_port}" \
      --file     "$config_file" 2>&1; then
    log_info "${node}: applied via Python TCP tunnel"
    apply_results["$node"]="OK-tunnel"
  else
    log_error "${node}: apply failed via both IPv6 and tunnel"
    apply_results["$node"]="FAILED"
  fi
done

# Kill any tunnel processes
for pid in "${tunnel_pids[@]}"; do
  kill "$pid" 2>/dev/null || true
done

# ── Wait for nodes to reboot and become reachable on IPv4 ────────────────────

log_info ""
log_info "=== Waiting for nodes to reboot and reach IPv4:50000 ==="

declare -A ipv4_results=()

for node in "${NODES[@]}"; do
  ipv4="${NODE_IPV4[$node]}"
  if wait_port_open_ipv4 "$ipv4" 50000 300 5; then
    ipv4_results["$node"]="OK"
  else
    ipv4_results["$node"]="TIMEOUT"
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Apply results for ${CLUSTER} ==="
all_ok=true
for node in "${NODES[@]}"; do
  apply_st="${apply_results[$node]:-SKIPPED}"
  ipv4_st="${ipv4_results[$node]:-N/A}"
  log_info "  ${node}: apply=${apply_st}  ipv4-after-reboot=${ipv4_st}"
  if [[ "$apply_st" == "FAILED" || "$ipv4_st" == "TIMEOUT" ]]; then
    all_ok=false
  fi
done

if $all_ok; then
  log_info ""
  log_info "All nodes applied and reachable on IPv4."
  log_info "Next step: run 05-bootstrap.sh ${CLUSTER}"
else
  log_error "Some nodes failed. Review errors above."
  exit 1
fi
