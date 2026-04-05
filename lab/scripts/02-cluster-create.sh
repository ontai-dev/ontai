#!/usr/bin/env bash
# lab/scripts/02-cluster-create.sh — create linked-clone QCOW2 disks and
# define libvirt domain XML for one cluster from golden backing files.
#
# Does NOT start VMs. Does NOT apply machine configs.
# Call 03-cluster-start.sh after this script.
#
# Prerequisites:
#   - Golden images exist in /var/lib/libvirt/images/ontai/golden/
#   - Golden image checksums match CHECKSUMS file
#
# All MACs, IPs, TAP names are hard-coded from the deterministic table.
#
# Usage: 02-cluster-create.sh <cluster-name>
#   cluster-name: ccs-mgmt | ccs-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tools virsh qemu-img sha256sum

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || fail_fast "Usage: $0 <cluster-name>  (ccs-mgmt | ccs-dev)"
[[ "$CLUSTER" == "ccs-mgmt" || "$CLUSTER" == "ccs-dev" ]] \
  || fail_fast "Unknown cluster '${CLUSTER}'. Valid values: ccs-mgmt, ccs-dev"

ISO="/var/lib/libvirt/images/ontai/talos-v1.9.3-metal-amd64.iso"
GOLDEN_DIR="/var/lib/libvirt/images/ontai/golden"
CLUSTER_DIR="/var/lib/libvirt/images/ontai/${CLUSTER}"
IFACE="talos-br0"

# ── Cluster node tables (hard-coded) ─────────────────────────────────────────
# All values from lab/CLAUDE.md deterministic MAC table.

if [ "$CLUSTER" = "ccs-mgmt" ]; then
  # cluster byte 01
  NODES=(ccs-mgmt-cp1 ccs-mgmt-cp2 ccs-mgmt-cp3 ccs-mgmt-w1 ccs-mgmt-w2)

  declare -A NODE_MAC=(
    [ccs-mgmt-cp1]="52:54:00:01:0a:01"
    [ccs-mgmt-cp2]="52:54:00:01:0a:02"
    [ccs-mgmt-cp3]="52:54:00:01:0a:03"
    [ccs-mgmt-w1]="52:54:00:01:0b:01"
    [ccs-mgmt-w2]="52:54:00:01:0b:02"
  )
  declare -A NODE_TAP=(
    [ccs-mgmt-cp1]="tap-0-2"
    [ccs-mgmt-cp2]="tap-0-3"
    [ccs-mgmt-cp3]="tap-0-4"
    [ccs-mgmt-w1]="tap-0-5"
    [ccs-mgmt-w2]="tap-0-6"
  )
  declare -A NODE_RAM=(
    [ccs-mgmt-cp1]="4096"
    [ccs-mgmt-cp2]="4096"
    [ccs-mgmt-cp3]="4096"
    [ccs-mgmt-w1]="8192"
    [ccs-mgmt-w2]="8192"
  )
  declare -A NODE_VCPUS=(
    [ccs-mgmt-cp1]="2"
    [ccs-mgmt-cp2]="2"
    [ccs-mgmt-cp3]="2"
    [ccs-mgmt-w1]="4"
    [ccs-mgmt-w2]="4"
  )
  # Golden backing files: cp nodes use golden-cp images, workers use golden-w images
  declare -A NODE_GOLDEN=(
    [ccs-mgmt-cp1]="golden-cp1-v1.qcow2"
    [ccs-mgmt-cp2]="golden-cp2-v1.qcow2"
    [ccs-mgmt-cp3]="golden-cp3-v1.qcow2"
    [ccs-mgmt-w1]="golden-w1-v1.qcow2"
    [ccs-mgmt-w2]="golden-w2-v1.qcow2"
  )

else  # ccs-dev — cluster byte 02
  NODES=(ccs-dev-cp1 ccs-dev-cp2 ccs-dev-cp3 ccs-dev-w1 ccs-dev-w2)

  declare -A NODE_MAC=(
    [ccs-dev-cp1]="52:54:00:02:0a:01"
    [ccs-dev-cp2]="52:54:00:02:0a:02"
    [ccs-dev-cp3]="52:54:00:02:0a:03"
    [ccs-dev-w1]="52:54:00:02:0b:01"
    [ccs-dev-w2]="52:54:00:02:0b:02"
  )
  declare -A NODE_TAP=(
    [ccs-dev-cp1]="tap-0-11"
    [ccs-dev-cp2]="tap-0-12"
    [ccs-dev-cp3]="tap-0-13"
    [ccs-dev-w1]="tap-0-14"
    [ccs-dev-w2]="tap-0-15"
  )
  declare -A NODE_RAM=(
    [ccs-dev-cp1]="4096"
    [ccs-dev-cp2]="4096"
    [ccs-dev-cp3]="4096"
    [ccs-dev-w1]="8192"
    [ccs-dev-w2]="8192"
  )
  declare -A NODE_VCPUS=(
    [ccs-dev-cp1]="2"
    [ccs-dev-cp2]="2"
    [ccs-dev-cp3]="2"
    [ccs-dev-w1]="4"
    [ccs-dev-w2]="4"
  )
  declare -A NODE_GOLDEN=(
    [ccs-dev-cp1]="golden-cp1-v1.qcow2"
    [ccs-dev-cp2]="golden-cp2-v1.qcow2"
    [ccs-dev-cp3]="golden-cp3-v1.qcow2"
    [ccs-dev-w1]="golden-w1-v1.qcow2"
    [ccs-dev-w2]="golden-w2-v1.qcow2"
  )
fi

# ── Preflight: verify golden images and checksums ─────────────────────────────

log_info "=== Verifying golden images ==="

CHECKSUMS_FILE="${GOLDEN_DIR}/CHECKSUMS"
[ -f "$CHECKSUMS_FILE" ] \
  || fail_fast "Golden CHECKSUMS file not found: ${CHECKSUMS_FILE}. Run 01-golden-create.sh first."

# Collect expected images (unique list for this cluster's roles)
declare -A seen_golden=()
for node in "${NODES[@]}"; do
  g="${NODE_GOLDEN[$node]}"
  seen_golden["$g"]=1
done

for img in "${!seen_golden[@]}"; do
  golden_path="${GOLDEN_DIR}/${img}"
  [ -f "$golden_path" ] \
    || fail_fast "Golden image not found: ${golden_path}. Run 01-golden-create.sh first."

  # Verify checksum
  expected_line="$(grep "$img" "$CHECKSUMS_FILE" 2>/dev/null || true)"
  if [ -z "$expected_line" ]; then
    fail_fast "No checksum entry for ${img} in ${CHECKSUMS_FILE}"
  fi

  actual_sum="$(sha256sum "${golden_path}" | awk '{print $1}')"
  expected_sum="$(echo "$expected_line" | awk '{print $1}')"
  if [ "$actual_sum" != "$expected_sum" ]; then
    fail_fast "Checksum mismatch for ${img}: expected ${expected_sum}, got ${actual_sum}"
  fi
  log_info "${img} checksum OK"
done

# ── Create cluster disk directory ─────────────────────────────────────────────

mkdir -p "$CLUSTER_DIR"

# ── Create linked clone disks and define domain XML ──────────────────────────

log_info "=== Creating linked-clone disks and defining libvirt domains for ${CLUSTER} ==="

for node in "${NODES[@]}"; do
  mac="${NODE_MAC[$node]}"
  tap="${NODE_TAP[$node]}"
  ram="${NODE_RAM[$node]}"
  vcpus="${NODE_VCPUS[$node]}"
  golden_img="${GOLDEN_DIR}/${NODE_GOLDEN[$node]}"
  clone_disk="${CLUSTER_DIR}/${node}.qcow2"

  # Create linked clone disk (qcow2 with backing file)
  if [ -f "$clone_disk" ]; then
    log_info "${clone_disk} already exists — skipping disk creation"
  else
    log_info "Creating linked clone: ${clone_disk} (backing: ${golden_img})"
    qemu-img create -f qcow2 -b "$golden_img" -F qcow2 "$clone_disk"
    sudo chown libvirt-qemu:kvm "$clone_disk" 2>/dev/null || true
    sudo chmod 664 "$clone_disk" 2>/dev/null || true
    log_info "${clone_disk} created"
  fi

  # Define domain XML
  if vm_is_defined "$node"; then
    log_info "${node} already defined — skipping domain definition"
    continue
  fi

  log_info "Defining domain ${node} (MAC=${mac} TAP=${tap} RAM=${ram}MB vCPU=${vcpus})"

  XML=$(mktemp /tmp/${CLUSTER}-${node}-XXXXXX.xml)
  cat > "$XML" <<DOMXML
<domain type='kvm'>
  <name>${node}</name>
  <memory unit='MiB'>${ram}</memory>
  <currentMemory unit='MiB'>${ram}</currentMemory>
  <vcpu placement='static'>${vcpus}</vcpu>
  <iothreads>1</iothreads>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='${vcpus}' threads='1'/>
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
      <source file='${clone_disk}'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </disk>
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
  log_info "${node} defined (not started)"
done

log_info ""
log_info "=== ${CLUSTER} domains defined ==="
log_info "Linked-clone disks: ${CLUSTER_DIR}/"
log_info "Next step: run 03-cluster-start.sh ${CLUSTER}"
