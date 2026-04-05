#!/usr/bin/env bash
# lab/scripts/01-golden-create.sh — create the golden cluster VMs, boot to
# Talos maintenance mode, capture standalone QCOW2 golden images.
#
# The golden cluster is a dedicated 5-node QEMU cluster whose sole purpose is
# to reach Talos maintenance mode (squashfs rootfs on disk, port 50000
# listening, zero identity) and be frozen as named QCOW2 images.
#
# Boot sequence:
#   1. VM boots from ISO — Talos installer writes squashfs rootfs to /dev/vda
#   2. VM reboots into maintenance mode from disk — port 50000 becomes available
#   3. We wait for 50000, then power off gracefully
#   4. Convert working disk to standalone golden image (no backing-file chain)
#   5. Record sha256 checksums
#
# All MACs, IPs, IPv6 addresses, and TAP names are hard-coded from the
# deterministic table in lab/CLAUDE.md — never generated at runtime.
#
# Idempotent: skips VMs/disks/images that already exist.
# Fails fast if ISO or required directories are missing.
#
# Usage: 01-golden-create.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools virsh qemu-img nc sha256sum

# ── Constants ─────────────────────────────────────────────────────────────────

ISO="/var/lib/libvirt/images/ontai/talos-v1.9.3-metal-amd64.iso"
WORK_DIR="/var/lib/libvirt/images/ontai"
GOLDEN_DIR="/var/lib/libvirt/images/ontai/golden"
IFACE="talos-br0"

# All golden VMs use QCOW2 (linked-clone exception for golden cluster).
# CP: 50 GB  Worker: 20 GB
# ─────────────────────────────────────────────────────────────────────────────
# Deterministic table — lab/CLAUDE.md §Deterministic MAC Address Table
# cluster byte 04 for golden
# ─────────────────────────────────────────────────────────────────────────────
NODES=(golden-cp1 golden-cp2 golden-cp3 golden-w1 golden-w2)

declare -A NODE_MAC=(
  [golden-cp1]="52:54:00:04:0a:01"
  [golden-cp2]="52:54:00:04:0a:02"
  [golden-cp3]="52:54:00:04:0a:03"
  [golden-w1]="52:54:00:04:0b:01"
  [golden-w2]="52:54:00:04:0b:02"
)

declare -A NODE_IP=(
  [golden-cp1]="10.20.0.31"
  [golden-cp2]="10.20.0.32"
  [golden-cp3]="10.20.0.33"
  [golden-w1]="10.20.0.34"
  [golden-w2]="10.20.0.35"
)

# Pre-computed EUI-64 IPv6 link-local addresses (never derived at runtime).
# MAC 52:54:00:04:0A:NN → first byte XOR 02 = 50; insert ff:fe → 5054:ff:fe04:aNn
declare -A NODE_IPV6=(
  [golden-cp1]="fe80::5054:ff:fe04:a01"
  [golden-cp2]="fe80::5054:ff:fe04:a02"
  [golden-cp3]="fe80::5054:ff:fe04:a03"
  [golden-w1]="fe80::5054:ff:fe04:b01"
  [golden-w2]="fe80::5054:ff:fe04:b02"
)

declare -A NODE_TAP=(
  [golden-cp1]="tap-0-31"
  [golden-cp2]="tap-0-32"
  [golden-cp3]="tap-0-33"
  [golden-w1]="tap-0-34"
  [golden-w2]="tap-0-35"
)

# Disk sizes: CP nodes 50 GB, workers 20 GB
declare -A NODE_DISK_SIZE=(
  [golden-cp1]="50G"
  [golden-cp2]="50G"
  [golden-cp3]="50G"
  [golden-w1]="20G"
  [golden-w2]="20G"
)

# All golden nodes: 2048 MB / 2 vCPU — only need to reach maintenance mode
RAM_MB=2048
VCPUS=2

# ── Preflight checks ──────────────────────────────────────────────────────────

[ -f "$ISO" ] || fail_fast "Talos ISO not found at ${ISO}"
mkdir -p "$GOLDEN_DIR"

# ── Phase 1: Create disks and define VMs ──────────────────────────────────────

log_info "=== Phase 1: create golden VM disks and define libvirt domains ==="

for node in "${NODES[@]}"; do
  mac="${NODE_MAC[$node]}"
  ip="${NODE_IP[$node]}"
  tap="${NODE_TAP[$node]}"
  disk_size="${NODE_DISK_SIZE[$node]}"
  work_disk="${WORK_DIR}/${node}-work.qcow2"

  if [ ! -f "$work_disk" ]; then
    log_info "Creating working disk ${work_disk} (${disk_size} qcow2)"
    qemu-img create -f qcow2 "$work_disk" "$disk_size"
    sudo chown libvirt-qemu:kvm "$work_disk" 2>/dev/null || true
    sudo chmod 664 "$work_disk" 2>/dev/null || true
  else
    log_info "${work_disk} already exists — skipping disk creation"
  fi

  if vm_is_defined "$node"; then
    log_info "${node} already defined — skipping domain definition"
    continue
  fi

  log_info "Defining domain ${node} (MAC=${mac} TAP=${tap} IP=${ip})"

  XML=$(mktemp /tmp/golden-${node}-XXXXXX.xml)
  cat > "$XML" <<DOMXML
<domain type='kvm'>
  <name>${node}</name>
  <memory unit='MiB'>${RAM_MB}</memory>
  <currentMemory unit='MiB'>${RAM_MB}</currentMemory>
  <vcpu placement='static'>${VCPUS}</vcpu>
  <iothreads>1</iothreads>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='${VCPUS}' threads='1'/>
  </cpu>
  <features><acpi/><apic/><vmport state='off'/></features>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap' iothread='1'/>
      <source file='${work_disk}'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${ISO}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='sata' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x1f' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pcie-root'/>
    <controller type='pci' index='1' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='1' port='0x10'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </controller>
    <controller type='pci' index='2' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='2' port='0x11'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x1'/>
    </controller>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
    </controller>
    <interface type='bridge'>
      <mac address='${mac}'/>
      <source bridge='${IFACE}'/>
      <target dev='${tap}'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'><model name='isa-serial'/></target>
    </serial>
    <console type='pty'><target type='serial' port='0'/></console>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='vga' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </video>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </controller>
    <memballoon model='none'/>
  </devices>
</domain>
DOMXML

  virsh define "$XML"
  rm -f "$XML"
  log_info "${node} defined"
done

# ── Phase 2: Start VMs and wait for port 50000 ────────────────────────────────

log_info "=== Phase 2: start golden VMs and wait for Talos maintenance mode ==="

for node in "${NODES[@]}"; do
  state="$(vm_state "$node")"
  if [ "$state" = "running" ]; then
    log_info "${node} is already running"
  elif [ "$state" = "shut off" ]; then
    log_info "Starting ${node}"
    virsh start "$node"
  else
    log_info "${node} state=${state} — attempting start"
    virsh start "$node" || true
  fi
done

# Wait for port 50000 on each node's IPv6 link-local address.
# Timeout 15 minutes to allow for ISO boot, squashfs install, reboot cycle.
for node in "${NODES[@]}"; do
  ipv6="${NODE_IPV6[$node]}%${IFACE}"
  wait_port_open "$ipv6" 50000 900 10
  log_info "${node} (${ipv6}) is in Talos maintenance mode"
done

# ── Phase 3: Graceful shutdown ────────────────────────────────────────────────

log_info "=== Phase 3: gracefully shut down all golden VMs ==="

for node in "${NODES[@]}"; do
  if [ "$(vm_state "$node")" = "running" ]; then
    log_info "Shutting down ${node}"
    virsh shutdown "$node"
  else
    log_info "${node} is not running — skipping shutdown"
  fi
done

for node in "${NODES[@]}"; do
  wait_vm_shutoff "$node" 120
done

log_info "All golden VMs are shut off"

# ── Phase 4: Convert working disks to standalone golden images ────────────────

log_info "=== Phase 4: convert working disks to standalone golden QCOW2 images ==="

for node in "${NODES[@]}"; do
  work_disk="${WORK_DIR}/${node}-work.qcow2"
  golden_img="${GOLDEN_DIR}/${node}-v1.qcow2"

  if [ -f "$golden_img" ]; then
    log_info "${golden_img} already exists — skipping conversion (delete to recreate)"
    continue
  fi

  [ -f "$work_disk" ] || fail_fast "Working disk not found: ${work_disk}"

  log_info "Converting ${work_disk} → ${golden_img}"
  qemu-img convert -O qcow2 -p "$work_disk" "$golden_img"
  sudo chown libvirt-qemu:kvm "$golden_img" 2>/dev/null || true
  sudo chmod 664 "$golden_img" 2>/dev/null || true
  log_info "${node} golden image written: ${golden_img}"
done

# ── Phase 5: Record checksums ─────────────────────────────────────────────────

log_info "=== Phase 5: recording sha256 checksums ==="

CHECKSUMS_FILE="${GOLDEN_DIR}/CHECKSUMS"
{
  echo "# Seam Platform — Golden Image Checksums"
  echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# Talos version: v1.9.3"
  echo "#"
  for node in "${NODES[@]}"; do
    golden_img="${GOLDEN_DIR}/${node}-v1.qcow2"
    if [ -f "$golden_img" ]; then
      sha256sum "$golden_img"
    fi
  done
} > "$CHECKSUMS_FILE"

log_info "Checksums written to ${CHECKSUMS_FILE}"
cat "$CHECKSUMS_FILE"

# ── Done ──────────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Golden image creation complete ==="
log_info "Golden images: ${GOLDEN_DIR}/"
for node in "${NODES[@]}"; do
  log_info "  ${node}-v1.qcow2"
done
log_info "Next step: run 02-cluster-create.sh <cluster-name>"
