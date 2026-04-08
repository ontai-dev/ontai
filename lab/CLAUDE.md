# LAB
# Load this at every lab session start. All invariants are constitutional.

---

## Identity

This lab runs on a Lenovo ThinkPad P-series (32 threads, 32GB RAM, Ubuntu 24.04).
Hypervisor: QEMU/KVM via libvirt. Bridge: talos-br0, subnet 10.20.0.1/24.
Host IP on bridge: 10.20.0.1 (also DNS and default gateway for all VMs).
Local OCI registry: http://10.20.0.1:5000 (Docker container: talos-fleet-registry).
Local Helm chart server: http://10.20.0.1:8888.
Talos ISO: /var/lib/libvirt/images/ontai/talos-v1.9.3-metal-amd64.iso
Golden images directory: /var/lib/libvirt/images/ontai/golden/
Cluster disk directory: /var/lib/libvirt/images/ontai/{cluster-name}/
Lab configs: ~/ontai/lab/configs/{cluster-name}/

---

## Cluster Registry

| Cluster   | Role        | IP Range         | VIP         | Status        |
|-----------|-------------|------------------|-------------|---------------|
| ccs-mgmt  | management  | 10.20.0.2–6      | 10.20.0.10  | N/A           |
| ccs-dev   | tenant/dev  | 10.20.0.11–15    | 10.20.0.15  | N/A           |


Max simultaneous running VMs: 10 total across all clusters.
ccs-mgmt must first run and is never torn down.

---

## Deterministic MAC Address Table

MAC scheme: 52:54:00 : {cluster-byte} : {role-byte} : {node-index}
Cluster bytes: mgmt=01, dev=02
Role bytes: control-plane=0A, worker=0B
Node index: 01, 02, 03

DO NOT create any VM with a random or unlisted MAC. Every MAC below is the only
valid MAC for that VM. Scripts must hard-code these values, never generate them.

| VM            | MAC               | IPv4        | IPv6 Link-Local (pre-computed)         |
|---------------|-------------------|-------------|----------------------------------------|
| ccs-mgmt-cp1  | 52:54:00:01:0A:01 | 10.20.0.2   | fe80::5054:ff:fe01:a01%talos-br0       |
| ccs-mgmt-cp2  | 52:54:00:01:0A:02 | 10.20.0.3   | fe80::5054:ff:fe01:a02%talos-br0       |
| ccs-mgmt-cp3  | 52:54:00:01:0A:03 | 10.20.0.4   | fe80::5054:ff:fe01:a03%talos-br0       |
| ccs-mgmt-w1   | 52:54:00:01:0B:01 | 10.20.0.5   | fe80::5054:ff:fe01:b01%talos-br0       |
| ccs-mgmt-w2   | 52:54:00:01:0B:02 | 10.20.0.6   | fe80::5054:ff:fe01:b02%talos-br0       |
| ccs-dev-cp1   | 52:54:00:02:0A:01 | 10.20.0.11  | fe80::5054:ff:fe02:a01%talos-br0       |
| ccs-dev-cp2   | 52:54:00:02:0A:02 | 10.20.0.12  | fe80::5054:ff:fe02:a02%talos-br0       |
| ccs-dev-cp3   | 52:54:00:02:0A:03 | 10.20.0.13  | fe80::5054:ff:fe02:a03%talos-br0       |
| ccs-dev-w1    | 52:54:00:02:0B:01 | 10.20.0.14  | fe80::5054:ff:fe02:b01%talos-br0       |
| ccs-dev-w2    | 52:54:00:02:0B:02 | 10.20.0.15  | fe80::5054:ff:fe02:b02%talos-br0       |


IPv6 derivation rule (EUI-64): flip bit 1 of first MAC byte (52 XOR 02 = 50),
insert ff:fe after byte 3. 52:54:00:02:0A:01 → 50:54:00:ff:fe:02:0A:01 → fe80::5054:ff:fe02:a01
Since MACs are deterministic, IPv6 addresses are deterministic. Never derive at runtime.

---

## VM Creation Rules

- CP nodes: raw disk format (.img), 50GB, cache=none, io=native, iothread=1, memballoon=none
- Worker nodes: qcow2 disk format, 20GB, cache=none, io=native, iothread=1, memballoon=none
- EXCEPTION for golden cluster: all nodes use qcow2 to enable linked-clone snapshots
- All nodes: cpu mode=host-passthrough, 2 vCPUs, 2048MB RAM minimum
- All nodes: bridge=talos-br0, MAC from the deterministic table above — never random
- All nodes: boot order cdrom first, then hd (ISO present at creation, removed after install)
- TAP name format: tap-{oct3}-{oct4} derived from the node IP

---

## Talos Machine Config Apply — Invariants

### Port 50000 is gRPC only
Never use curl against port 50000. Use only: talosctl apply-config --insecure --nodes <ip> --file <config>
curl http://ip:50000 returns connection reset — this is expected and not a network problem.

### First apply always uses IPv6 link-local (IPv4 not reachable until config applied)
Use pre-computed IPv6 addresses from the table above. Do not derive at runtime.
talosctl apply-config --insecure --nodes "[fe80::...%25talos-br0]" --file <config>
The %25 is URL-encoded % — required for link-local zone ID. Both --nodes and --endpoints must use it.

### IPv6 fallback via Python TCP tunnel
If %25 zone encoding fails with talosctl, use a Python tunnel:
  python3 -c "import socket,threading; ..."  mapping 127.0.0.1:50001 → [fe80::...%talos-br0]:50000
Then target talosctl at 127.0.0.1:50001 for that node.
This pattern is documented in full in talos-fleet-operator/CLAUDE.md CARRY-FORWARD INVARIANTS.

### GRUB stuck at boot menu (fresh VM)
Symptom: VM CPU time barely increases over many minutes (~70s in 20+ minutes).
GRUB timeout may not fire if menu is already showing from a prior keypress reset.
Fix: virsh send-key <vm-name> KEY_ENTER for each stuck VM.
This is a HUMAN action — Claude Code never runs virsh interactively.

### Registry mirrors mandatory in every machine config
Every generated machine config must include the following mirror block.
Without it, containerd uses HTTPS for 10.20.0.1:5000 and fails with HTTP/HTTPS mismatch.
Required endpoints: ghcr.io, registry.k8s.io, docker.io, and 10.20.0.1:5000 self-mirror.
The http:// prefix is sufficient — do NOT add registries.config.tls.insecureSkipVerify.
Adding TLS config for an http:// endpoint prevents containerd from connecting.

### talosconfig with empty endpoints
Operator-generated talosconfig files have endpoints=[].
All talosctl commands using such a talosconfig must pass --endpoints <node-ip> explicitly.
talosctl fails silently with "failed to determine endpoints" if endpoints=[] and flag is absent.

### CNI: none and kube-proxy: disabled are mandatory for management and tenant clusters
Cilium is always the CNI, deployed post-bootstrap from 10.20.0.1:8888.
kube-proxy must be disabled — Cilium replaces it via eBPF.
certSANs must include the cluster VIP for management cluster (10.20.0.10).

---

## Snapshot Workflow — Golden Cluster

### What is the golden cluster
A dedicated QEMU cluster (separate from ccs-mgmt, ccs-dev) whose sole purpose
is to reach maintenance mode (Talos rootfs installed, port 50000 listening, zero identity)
and be frozen as a set of named QCOW2 snapshot images.

The golden cluster uses the IP range 10.20.0.31–36 and the MAC range:
  golden-cp1: 52:54:00:04:0A:01 / 10.20.0.31
  golden-cp2: 52:54:00:04:0A:02 / 10.20.0.32
  golden-cp3: 52:54:00:04:0A:03 / 10.20.0.33
  golden-w1:  52:54:00:04:0B:01 / 10.20.0.34
  golden-w2:  52:54:00:04:0B:02 / 10.20.0.35

All golden VMs use QCOW2 format (not raw) to enable linked clone semantics.

### Golden snapshot sequence (one-time)

Step 1: Create all six golden VMs with QCOW2 disks and deterministic MACs above.
Step 2: Boot from ISO. The Talos installer writes the squashfs rootfs to /dev/vda and reboots.
Step 3: After the automatic reboot, each node enters maintenance mode (port 50000 listening).
        DO NOT apply any machine config. This is the target golden state.
Step 4: Gracefully power off all six VMs via virsh shutdown. Wait for all to reach shut-off.
        DO NOT snapshot running VMs — disk state must be consistent.
Step 5: For each VM disk, create a standalone QCOW2 copy via qemu-img convert (not a linked clone).
        This produces six independent golden images with no backing-file dependency.
        Name: golden-cp1-v1.qcow2 through golden-w3-v1.qcow2
        Store in: /var/lib/libvirt/images/ontai/golden/
Step 6: Record sha256 checksum of each golden image in /var/lib/libvirt/images/ontai/golden/CHECKSUMS

### Stamping a new cluster from golden images

Step 1: Verify the six golden images exist and checksums match CHECKSUMS file.
Step 2: For each node in the target cluster, create a linked clone QCOW2 using the corresponding
        golden image as the backing file. Backing file must remain intact for clone lifetime.
        Store clones in /var/lib/libvirt/images/ontai/{cluster-name}/
Step 3: Define libvirt domain XML for each node using deterministic MAC from the table above,
        the cloned disk path, and the cluster-specific VM name and TAP interface name.
        Do not reuse golden VM domain XML — define fresh domains.
Step 4: Generate machine configs with talosctl gen config for the management cluster. For Seam-native bootstrap, apply full machine config and proceed through bootstrap. For CAPI-managed clusters, Platform operator drives the machine config injection — maintenance mode is the handoff point and the Compiler does not bootstrap manually..
        Patch every config with: cluster name, VIP, node hostname, node IP,
        registry mirrors (all four), cni:none, proxy.disabled:true, certSANs (VIP).
Step 5: Start all six VMs. Each boots from the clone directly into maintenance mode.
        No ISO, no OS installation — the rootfs is already on disk from the golden snapshot.
Step 6: Apply machine config to each node via IPv6 link-local using pre-computed addresses.
        Use talosctl apply-config --insecure for all nodes.
Step 7: Wait for nodes to reboot and rejoin on their assigned IPv4 addresses.
Step 8: Run talosctl bootstrap against cp1 exactly once.
Step 9: Run talosctl health and kubectl get nodes to verify all nodes NotReady (CNI and kubeproxy is missing).
Step 10: Copy both talosconfig and kubeconfig for Compiler to do its work

### Cluster teardown (preserves golden images)

Step 1: Gracefully shut down all VMs via virsh shutdown.
Step 2: Delete libvirt domain definitions via virsh undefine for each VM.
Step 3: Delete the linked clone disk files in /var/lib/libvirt/images/ontai/{cluster-name}/.
        The golden backing files in /golden/ are never touched during teardown.
Step 4: Remove DHCP reservations or dnsmasq entries for the cluster IP range if applicable.

---

## Kueue Version Invariant

kueue v0.7.0 references gcr.io/kubebuilder/kube-rbac-proxy which is no longer available.
Always use kueue v0.16.2 or later.
kube-rbac-proxy must be pulled from quay.io/brancz/kube-rbac-proxy and pushed to 10.20.0.1:5000.
The kueue manifest at configs/charts/kueue-v0.16.2.yaml has all image references pre-substituted
to point at 10.20.0.1:5000.

---

## Cilium Deployment Invariants

Deploy from local Helm chart server: http://10.20.0.1:8888
Two-phase install: helm install then helm upgrade (Cilium requires the two-phase sequence on Talos).
Generic Cilium values will NOT work on Talos. Use the exact flags below.

### Required Helm values for Talos clusters (all flags are mandatory)

```
routingMode: native
bpf.masquerade: "true"
l2announcements.enabled: "true"
MTU: "1450"
ipv4NativeRoutingCIDR: 10.244.0.0/16
kubeProxyReplacement: "true"
k8sServiceHost: <cluster-VIP>        # e.g. 10.20.0.10 for ccs-mgmt
k8sServicePort: "6443"
cni.exclusive: "false"
nodeinit.enabled: "false"
cgroup.autoMount.enabled: "false"
cgroup.hostRoot: /sys/fs/cgroup
securityContext.capabilities.ciliumAgent:
  - CHOWN
  - KILL
  - NET_ADMIN
  - NET_RAW
  - IPC_LOCK
  - SYS_ADMIN
  - SYS_RESOURCE
  - DAC_OVERRIDE
  - FOWNER
  - SETGID
  - SETUID
securityContext.capabilities.cleanCiliumState:
  - NET_ADMIN
  - SYS_ADMIN
  - SYS_RESOURCE
```

k8sServiceHost and k8sServicePort tell Cilium to reach the API server via the
cluster VIP rather than the in-cluster DNS path — required because kube-proxy is
disabled and Cilium is bootstrapping its own replacement service routing.

cgroup.autoMount must be false and cgroup.hostRoot must be /sys/fs/cgroup because
Talos mounts the cgroup hierarchy itself; Cilium must not attempt to remount it.

nodeinit.enabled must be false — the Talos kernel is already initialised; running
node-init produces permission errors and a broken Cilium install.

cni.exclusive=false allows the Talos CNI slot to coexist during the Cilium install
phase without Cilium overwriting the CNI config prematurely.

---

## Noticable Actions (If needed)

- virsh send-key (GRUB boot menu fix)



---