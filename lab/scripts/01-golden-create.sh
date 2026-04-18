#!/usr/bin/env bash
# lab/scripts/01-golden-create.sh — create the golden cluster VMs, install
# Talos to disk, wipe identity, and freeze as standalone QCOW2 golden images.
#
# Boot sequence:
#   1. VM boots from ISO — Talos is in maintenance mode (port 50000 open)
#   2. apply-config --insecure triggers installer → writes squashfs to /dev/vda → reboots
#   3. VM reboots into maintenance mode from disk — port 50000 open again
#   4. talosctl reset wipes STATE+EPHEMERAL (machine config removed, zero identity)
#   5. VM reboots back into maintenance mode — TYPE=unknown, STAGE=Maintenance
#   6. Power off gracefully
#   7. Convert working disk to standalone golden image (no backing-file chain)
#   8. Record sha256 checksums
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

check_tools virsh qemu-img nc sha256sum talosctl

# ── Constants ─────────────────────────────────────────────────────────────────

ISO="/var/lib/libvirt/images/ontai/talos-v1.9.3-metal-amd64.iso"
WORK_DIR="/var/lib/libvirt/images/ontai"
GOLDEN_DIR="/var/lib/libvirt/images/ontai/golden"
IFACE="talos-br0"

TALOS_VERSION="v1.9.3"
KUBERNETES_VERSION="1.32.3"
INSTALL_IMAGE="ghcr.io/siderolabs/installer:${TALOS_VERSION}"
INSTALL_DISK="/dev/vda"

# Temporary machine configs — generated fresh each run, discarded after reset
GOLDEN_CONFIG_DIR="/tmp/golden-config-$$"

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
  [golden-cp1]="10.20.0.101"
  [golden-cp2]="10.20.0.102"
  [golden-cp3]="10.20.0.103"
  [golden-w1]="10.20.0.117"
  [golden-w2]="10.20.0.118"
)

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

declare -A NODE_DISK_SIZE=(
  [golden-cp1]="50G"
  [golden-cp2]="50G"
  [golden-cp3]="50G"
  [golden-w1]="20G"
  [golden-w2]="20G"
)

declare -A NODE_ROLE=(
  [golden-cp1]="controlplane"
  [golden-cp2]="controlplane"
  [golden-cp3]="controlplane"
  [golden-w1]="worker"
  [golden-w2]="worker"
)

RAM_MB=2048
VCPUS=2

# ── Cleanup on exit ───────────────────────────────────────────────────────────

cleanup() {
  rm -rf "$GOLDEN_CONFIG_DIR"
}
trap cleanup EXIT

# ── Preflight checks ──────────────────────────────────────────────────────────

[ -f "$ISO" ] || fail_fast "Talos ISO not found at ${ISO}"
mkdir -p "$GOLDEN_DIR"
mkdir -p "$GOLDEN_CONFIG_DIR"

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

# ── Phase 2: Generate temporary machine configs ───────────────────────────────

log_info "=== Phase 2: generate temporary machine configs ==="

# Use cp1 IP as the dummy endpoint — golden configs are only used to trigger
# the installer and are wiped before image conversion. The endpoint value
# is irrelevant since no cluster is ever bootstrapped from golden images.
FIRST_CP_IP="${NODE_IP[golden-cp1]}"

talosctl gen config golden-install "https://${FIRST_CP_IP}:6443" \
  --talos-version "${TALOS_VERSION}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --install-image "${INSTALL_IMAGE}" \
  --install-disk "${INSTALL_DISK}" \
  --output "${GOLDEN_CONFIG_DIR}"

log_info "Machine configs generated at ${GOLDEN_CONFIG_DIR}"

# ── Phase 3: Start VMs and wait for ISO maintenance mode ──────────────────────

log_info "=== Phase 3: start golden VMs and wait for ISO maintenance mode ==="

for node in "${NODES[@]}"; do
  state="$(vm_state "$node")"
  if [ "$state" = "running" ]; then
    log_info "${node} is already running"
  else
    log_info "Starting ${node}"
    virsh start "$node" || true
  fi
done

# Wait for ISO maintenance mode — port 50000 answering from the ISO itself
for node in "${NODES[@]}"; do
  ip="${NODE_IP[$node]}"
  wait_port_open "$ip" 50000 300 5
  log_info "${node} (${ip}) ISO maintenance mode confirmed"
done

# ── Phase 4: Apply configs to trigger installation ────────────────────────────

log_info "=== Phase 4: apply machine configs to trigger Talos installation ==="

for node in "${NODES[@]}"; do
  ip="${NODE_IP[$node]}"
  role="${NODE_ROLE[$node]}"

  if [ "$role" = "controlplane" ]; then
    config_file="${GOLDEN_CONFIG_DIR}/controlplane.yaml"
  else
    config_file="${GOLDEN_CONFIG_DIR}/worker.yaml"
  fi

  log_info "Applying ${role} config to ${node} (${ip})"
  talosctl apply-config --insecure --nodes "$ip" --file "$config_file"
done

log_info "Configs applied — nodes are installing Talos to disk and will reboot"

# ── Phase 5: Wait for post-install disk maintenance mode ─────────────────────

log_info "=== Phase 5: wait for post-install maintenance mode (disk boot) ==="

# Nodes reboot after install — allow time for the reboot cycle before polling
log_info "Sleeping 30s to allow install + reboot cycle to begin..."
sleep 30

for node in "${NODES[@]}"; do
  ip="${NODE_IP[$node]}"
  # Timeout 600s — install + reboot can take up to 3 minutes per node
  wait_port_open "$ip" 50000 600 10
  log_info "${node} (${ip}) post-install maintenance mode confirmed"
done

# ── Phase 6: Reset nodes to wipe machine config (zero identity) ───────────────

log_info "=== Phase 6: reset nodes to wipe STATE+EPHEMERAL (zero identity) ==="

TALOSCONFIG="${GOLDEN_CONFIG_DIR}/talosconfig"

for node in "${NODES[@]}"; do
  ip="${NODE_IP[$node]}"
  log_info "Resetting ${node} (${ip}) — wiping STATE and EPHEMERAL"
  talosctl reset \
    --talosconfig "$TALOSCONFIG" \
    --endpoints "$ip" \
    --nodes "$ip" \
    --graceful=false \
    --reboot \
    --system-labels-to-wipe STATE \
    --system-labels-to-wipe EPHEMERAL
done

log_info "Reset commands issued — nodes are rebooting to zero-identity maintenance mode"

# ── Phase 7: Wait for zero-identity maintenance mode ─────────────────────────

log_info "=== Phase 7: wait for zero-identity maintenance mode ==="

log_info "Sleeping 30s to allow reset + reboot cycle to begin..."
sleep 30

for node in "${NODES[@]}"; do
  ip="${NODE_IP[$node]}"
  wait_port_open "$ip" 50000 300 5
  log_info "${node} (${ip}) zero-identity maintenance mode confirmed"
done

# ── Phase 8: Graceful shutdown ────────────────────────────────────────────────

log_info "=== Phase 8: shut down all golden VMs ==="

for node in "${NODES[@]}"; do
  if [ "$(vm_state "$node")" = "running" ]; then
    log_info "Shutting down ${node}"
    virsh destroy "$node"
  else
    log_info "${node} is not running — skipping"
  fi
done

log_info "All golden VMs shut off"

# ── Phase 9: Convert working disks to standalone golden images ────────────────

log_info "=== Phase 9: convert working disks to standalone golden QCOW2 images ==="

for node in "${NODES[@]}"; do
  work_disk="${WORK_DIR}/${node}-work.qcow2"
  golden_img="${GOLDEN_DIR}/${node}-v1.qcow2"

  if [ -f "$golden_img" ]; then
    log_info "${golden_img} already exists — skipping (delete to recreate)"
    continue
  fi

  [ -f "$work_disk" ] || fail_fast "Working disk not found: ${work_disk}"

  log_info "Converting ${work_disk} → ${golden_img}"
  qemu-img convert -O qcow2 -p "$work_disk" "$golden_img"
  sudo chown libvirt-qemu:kvm "$golden_img" 2>/dev/null || true
  sudo chmod 664 "$golden_img" 2>/dev/null || true

  actual_size=$(qemu-img info "$golden_img" | grep '^disk size:' | awk '{print $3}')
  log_info "${node} golden image written: ${golden_img} (disk size: ${actual_size})"
done

# ── Phase 10: Record checksums ────────────────────────────────────────────────

log_info "=== Phase 10: recording sha256 checksums ==="

CHECKSUMS_FILE="${GOLDEN_DIR}/CHECKSUMS"
{
  echo "# ONT Lab — Golden Image Checksums"
  echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# Talos version: ${TALOS_VERSION}"
  echo "# Kubernetes version: v${KUBERNETES_VERSION}"
  echo "# Stage: Maintenance (zero identity, STATE+EPHEMERAL wiped)"
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
log_info "Talos ${TALOS_VERSION} / Kubernetes v${KUBERNETES_VERSION}"
log_info "Golden images: ${GOLDEN_DIR}/"
for node in "${NODES[@]}"; do
  log_info "  ${node}-v1.qcow2"
done
log_info "Next step: run 02-cluster-create.sh <cluster-name>"