#!/usr/bin/env bash
# lab/scripts/lib/common.sh — shared functions sourced by all lab scripts.
# Source with: source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# All functions assume set -euo pipefail is active in the caller.

# ── Logging ──────────────────────────────────────────────────────────────────

log_info() {
  echo "[INFO]  $(date '+%H:%M:%S')  $*"
}

log_error() {
  echo "[ERROR] $(date '+%H:%M:%S')  $*" >&2
}

# fail_fast MESSAGE — print error and exit 1.
fail_fast() {
  log_error "$*"
  exit 1
}

# ── Tool verification ─────────────────────────────────────────────────────────

# check_tools TOOL [TOOL...] — exits 1 with clear message if any tool is missing.
check_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    fail_fast "Required tools not found on PATH: ${missing[*]}"
  fi
}

# ── Port waiting ──────────────────────────────────────────────────────────────

# wait_port_open HOST PORT [TIMEOUT_SECS] [INTERVAL_SECS]
# Polls HOST:PORT with nc until open or timeout.
# For IPv6 link-local pass the full zone address: "fe80::...%iface"
# Uses -6 flag automatically when address contains ':'.
wait_port_open() {
  local host="$1"
  local port="$2"
  local timeout="${3:-300}"
  local interval="${4:-5}"
  local elapsed=0

  local nc_extra=()
  if [[ "$host" == *:* ]]; then
    nc_extra=(-6)
  fi

  log_info "Waiting for ${host}:${port} (timeout ${timeout}s) ..."
  while ! nc "${nc_extra[@]}" -z -w3 "$host" "$port" 2>/dev/null; do
    if [ "$elapsed" -ge "$timeout" ]; then
      log_error "Timed out waiting for ${host}:${port} after ${timeout}s"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
    log_info "  ... still waiting (${elapsed}s elapsed)"
  done
  log_info "${host}:${port} is open"
}

# wait_port_open_ipv4 IP PORT [TIMEOUT_SECS] [INTERVAL_SECS]
# Explicit IPv4-only nc check.
wait_port_open_ipv4() {
  local ip="$1"
  local port="$2"
  local timeout="${3:-300}"
  local interval="${4:-5}"
  local elapsed=0

  log_info "Waiting for ${ip}:${port} IPv4 (timeout ${timeout}s) ..."
  while ! nc -4 -z -w3 "$ip" "$port" 2>/dev/null; do
    if [ "$elapsed" -ge "$timeout" ]; then
      log_error "Timed out waiting for ${ip}:${port} after ${timeout}s"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
    log_info "  ... still waiting (${elapsed}s elapsed)"
  done
  log_info "${ip}:${port} is open"
}

# ── IP reachability ───────────────────────────────────────────────────────────

# wait_ipv4_reachable IP [TIMEOUT_SECS] [INTERVAL_SECS]
# Polls ping until the host responds or timeout expires.
wait_ipv4_reachable() {
  local ip="$1"
  local timeout="${2:-180}"
  local interval="${3:-5}"
  local elapsed=0

  log_info "Waiting for ${ip} ping reachability (timeout ${timeout}s) ..."
  while ! ping -c1 -W2 "$ip" &>/dev/null; do
    if [ "$elapsed" -ge "$timeout" ]; then
      log_error "Timed out waiting for ping response from ${ip} after ${timeout}s"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  log_info "${ip} is reachable"
}

# ── virsh helpers ─────────────────────────────────────────────────────────────

# vm_is_defined VM_NAME — returns 0 if domain is defined in libvirt.
vm_is_defined() {
  virsh dominfo "$1" &>/dev/null
}

# vm_state VM_NAME — prints current domain state string.
vm_state() {
  virsh domstate "$1" 2>/dev/null | tr -d ' '
}

# wait_vm_shutoff VM_NAME [TIMEOUT_SECS] — waits for domain to reach shut-off.
wait_vm_shutoff() {
  local name="$1"
  local timeout="${2:-120}"
  local elapsed=0
  local interval=3

  log_info "Waiting for ${name} to reach shut-off (timeout ${timeout}s) ..."
  while [ "$(vm_state "$name")" != "shut off" ]; do
    if [ "$elapsed" -ge "$timeout" ]; then
      log_error "Timed out waiting for ${name} to shut off after ${timeout}s"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  log_info "${name} is shut off"
}
