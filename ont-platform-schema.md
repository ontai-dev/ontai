# ont-platform-schema
> API Group: platform.ontai.dev
> Operator: ont-platform
> CAPI Providers: cluster.x-k8s.io, bootstrap.cluster.x-k8s.io, infrastructure.cluster.x-k8s.io
> Amended: 2026-03-30 — CAPI adopted for target cluster lifecycle. Management cluster
>   bootstrap unchanged. ONT InfrastructureMachine CRD introduced. Kueue scoped to
>   ont-infra quota profile. Operational CRDs retained where CAPI has no equivalent.

---

## 1. Domain Boundary

ont-platform owns the complete lifecycle of Talos clusters and all tenant
coordination. It does this by composing CAPI primitives for target cluster
lifecycle while preserving ONT's governing principles — declarative, versioned,
auditable, and security-first.

ont-platform is the CAPI management plane operator. It creates and owns CAPI
objects (Cluster, TalosControlPlane, MachineDeployment, ONTInfrastructureMachine)
as children of the ONT TalosCluster CR. CAPI controllers reconcile those objects
to actual cluster state through the ONT Infrastructure Provider and CABPT.

**What changes with CAPI adoption:**
- Target cluster lifecycle (bootstrap, upgrade, scale, health) is delegated to CAPI.
- The ONT Infrastructure Provider (part of ont-platform) delivers machineconfigs
  to nodes on port 50000 — it is the Talos-specific infrastructure layer.
- Kueue Jobs are no longer used for cluster lifecycle operations.
- Kueue is retained as a prerequisite exclusively for ont-infra pack-deploy Jobs.
- CAPI provides the observability (Machine status, Cluster conditions, events)
  that Kueue Jobs previously provided for cluster operations.

**What does not change:**
- Management cluster bootstrap remains ONT-native. CAPI cannot bootstrap the
  cluster it runs on. See Section 3 for the unchanged management cluster path.
- All ONT security plane rules. CAPI's RBAC goes through ont-security intake.
- ont-security deploys before CAPI. CAPI is installed in the enable phase after
  ont-security is operational.
- TalosCluster is still the ONT root CR for every cluster. CAPI objects are
  children of TalosCluster, not the other way around.
- Operational CRDs with no CAPI equivalent (TalosBackup, TalosEtcdMaintenance,
  TalosPKIRotation, TalosRecovery) remain and use ont-runner capabilities
  invoked via direct controller reconciliation.
- ont-platform creates tenant namespaces. Sole namespace authority unchanged.

---

## 2. CAPI Provider Architecture

### 2.1 Providers Installed on Management Cluster

**CAPI Core** (cluster.x-k8s.io) — Cluster, Machine, MachineDeployment,
MachineSet, MachineHealthCheck controllers. These are the battle-tested cluster
lifecycle primitives. Installed via OperatorManifest in the enable phase, after
ont-security.

**CABPT** (bootstrap.cluster.x-k8s.io) — Cluster API Bootstrap Provider Talos.
Generates TalosConfig and renders machineconfigs per Machine. Patches TalosConfig
with cluster-specific CNI=none and kernel parameters needed for Cilium. CABPT is
the source of rendered machineconfig data that the ONT Infrastructure Provider
delivers to nodes.

**ONT Infrastructure Provider** — a purpose-built ont-platform component that
implements the CAPI InfrastructureCluster and InfrastructureMachine contracts.
It does not call any cloud API. It watches ONTInfrastructureCluster and
ONTInfrastructureMachine objects and delivers machineconfigs to pre-provisioned
Talos nodes on port 50000 using the talos goclient embedded in the provider binary.
This is the only place in ont-platform that uses the talos goclient after bootstrap.
The provider is a distroless Go binary — talos goclient + kube goclient only.

### 2.2 CAPI Object Ownership

ont-platform's TalosCluster reconciler creates and owns:
- ONTInfrastructureCluster (infra reference for the CAPI Cluster)
- cluster.x-k8s.io/Cluster (owns TalosControlPlane and MachineDeployments)
- TalosControlPlane (CACPPT — control plane management)
- MachineDeployment per node role (control plane, worker)
- TalosConfigTemplate (CABPT — machineconfig generation template with CNI patches)
- ONTInfrastructureMachineTemplate (template for ONTInfrastructureMachine per node)

These are all created in the tenant-{cluster-name} namespace and owned by the
TalosCluster CR via ownerReference. Deleting TalosCluster cascades to all owned
CAPI objects through Kubernetes garbage collection, which triggers CAPI's own
deletion reconciliation. ONT finalizers on TalosCluster gate this to ensure
security plane cleanup happens before cascade.

### 2.3 Cilium CNI Integration

Every TalosConfigTemplate created by ont-platform includes:
- cluster.network.cni.name: none (disables default CNI, required for Cilium)
- BPF kernel parameters in machine config patches
- Cilium-required sysctl values

After CAPI bootstraps the cluster (nodes reach Running state but are NotReady
because no CNI is present), the ClusterAssignment with bootstrapFlag=true triggers
a PackExecution for the Cilium ClusterPack. This is the first pack deployed to
every cluster. Nodes transition to Ready only after Cilium is up.

The CAPI MachineHealthCheck is configured with a tolerance window for the CNI
installation period — nodes are not remediated during this window.

The Cilium ClusterPack is compiled per-cluster on the workstation with values
specific to the cluster endpoint, IPAM mode, L2 announcement configuration, MTU,
and routing mode. It is not a generic pack — it carries the cluster endpoint
address at compile time.

---

## 3. Management Cluster Bootstrap — Unchanged

Management cluster bootstrap does not use CAPI. CAPI cannot bootstrap the cluster
it runs on. The management cluster bootstrap path is:

Human runs ont-runner compile mode → generates machineconfigs, SOPS-encrypts
secrets → secrets committed to git → TalosCluster CR (mode: bootstrap) committed
to git → GitOps applies to a temporary Kubernetes context (or direct kubectl) →
ont-platform generates a bootstrap Job using ont-runner directly → runner pushes
machineconfigs to seed nodes on port 50000 → etcd initializes → Kubernetes API
comes up → enable phase installs ont-security first, then CAPI providers and
remaining prerequisites, then other operators.

After the management cluster exists, CAPI is installed and manages only target
clusters. The management cluster's own TalosCluster CR in ont-system has
mode: bootstrap and no CAPI children — management cluster lifecycle is not
CAPI-managed.

---

## 4. ONT InfrastructureMachine CRD

### ONTInfrastructureMachine

Scope: Namespaced — tenant-{cluster-name}
Short name: oim
API group: infrastructure.cluster.x-k8s.io (CAPI infrastructure contract)

Wraps a pre-provisioned node IP address and its connection parameters. This is the
ONT-native implementation of the CAPI InfrastructureMachine contract. One
ONTInfrastructureMachine per node in the cluster.

The human (or GitOps) declares the available node IPs as ONTInfrastructureMachine
objects in the tenant namespace before the cluster is bootstrapped. The ONT
Infrastructure Provider watches for CAPI Machine objects that reference these and
delivers the CABPT-rendered machineconfig to the declared IP on port 50000.

Key spec fields:
- address: the pre-provisioned node IP address reachable on port 50000.
- port: Talos maintenance API port. Default 50000.
- talosConfigSecretRef: reference to the talosconfig secret in ont-system that
  the provider uses to authenticate the ApplyConfiguration call.
- nodeRole: controlplane or worker. Must match the MachineDeployment role.

Status fields (set by the ONT Infrastructure Provider):
- ready: bool. Set to true after machineconfig is applied and the node transitions
  out of maintenance mode.
- machineConfigApplied: bool.
- providerID: the provider ID string written back to the CAPI Machine object.
  Format: talos://{cluster-name}/{node-ip}

CAPI contract compliance: ONTInfrastructureMachine implements the InfrastructureMachine
contract by setting status.ready=true when the machine is provisioned, and writing
spec.providerID back to the owning Machine object.

---

### ONTInfrastructureCluster

Scope: Namespaced — tenant-{cluster-name}
Short name: oic
API group: infrastructure.cluster.x-k8s.io

The cluster-level CAPI infrastructure reference. Holds the cluster endpoint and
any cluster-wide infrastructure parameters. One per cluster. Owned by the CAPI
Cluster object.

Key spec fields:
- controlPlaneEndpoint.host: the VIP or first control plane IP. Written into
  the CAPI Cluster object and into all generated machineconfigs via CABPT.
- controlPlaneEndpoint.port: Kubernetes API port. Default 6443.

Status fields:
- ready: bool. Set to true after all control plane ONTInfrastructureMachine
  objects have status.ready=true.

---

## 5. CRDs — ONT-Native (No CAPI Equivalent)

These CRDs remain in ont-platform. They do not delegate to CAPI because CAPI
has no equivalent concept. They use ont-runner capabilities invoked via
direct controller-Job submission (not Kueue — these are targeted operational
Jobs run against the cluster using secrets from ont-system).

### TalosCluster

Scope: Namespaced — ont-system (management), tenant-{cluster-name} (target)
Short name: tc
Lives in: git and management cluster.

The ONT root CR for every cluster. For target clusters, TalosCluster owns all
CAPI objects as children. For the management cluster, TalosCluster has no CAPI
children — it is the bootstrap record and operational anchor.

spec.mode (v1alpha1 only): bootstrap or import. As before.

New fields introduced with CAPI adoption:
- capi.enabled: bool. True for all target clusters. False for management cluster.
  When true, the TalosCluster reconciler creates CAPI objects. When false, it
  follows the direct bootstrap path.
- capi.talosVersion: Talos version to pass to TalosConfigTemplate and CABPT.
- capi.kubernetesVersion: Kubernetes version for TalosControlPlane.
- capi.controlPlane.replicas: number of control plane nodes.
- capi.workers: list of worker pools, each with a name, replica count, and
  list of ONTInfrastructureMachine names pre-provisioned for that pool.
- capi.ciliumPackRef: the ClusterPack name and version for Cilium. Applied
  as the first pack via ClusterAssignment bootstrapFlag after cluster reaches
  Running state.

status.origin: bootstrapped or imported. Unchanged.
status.capiClusterRef: reference to the owned CAPI Cluster object.
Status conditions: Ready, Bootstrapping, Importing, Degraded, CiliumPending.

CiliumPending is a new condition — set when the cluster reaches CAPI Running
state but the Cilium ClusterPack has not yet reached PackInstance.Ready. Nodes
are NotReady during this window. This is expected and not a degraded state.

---

### TalosBackup

Scope: Namespaced — tenant-{cluster-name}
Short name: tb
Named runner capability: etcd-backup

CAPI has no etcd backup concept. This CRD and its runner capability remain
unchanged. Uses ont-runner executor Job with talosconfig and kubeconfig secrets
mounted from ont-system.

Key spec fields: clusterRef, schedule, s3Destination, includeEtcd, includeMachineConfig.

---

### TalosEtcdMaintenance

Scope: Namespaced — tenant-{cluster-name}
Short name: tem
Named runner capability: etcd-maintenance

CAPI has no etcd maintenance concept. Remains unchanged.
Key spec fields: clusterRef, defrag, snapshot.

---

### TalosPKIRotation

Scope: Namespaced — tenant-{cluster-name}
Short name: tpr
Named runner capability: pki-rotate

CAPI has no PKI rotation concept for Talos. Remains unchanged.
Updates talosconfig secret in ont-system after rotation.
Key spec fields: clusterRef.

---

### TalosRecovery

Scope: Namespaced — tenant-{cluster-name}
Short name: trec
Named runner capability: etcd-restore

Disaster recovery from S3 etcd snapshot. CAPI cannot restore a failed cluster.
Remains unchanged.
Key spec fields: clusterRef, s3SnapshotPath, targetNodes.

---

### TalosHardeningProfile

Scope: Namespaced
Short name: thp

Reusable hardening ruleset. Referenced by TalosCluster at CAPI TalosConfigTemplate
generation time — patches are merged into the TalosConfigTemplate before CABPT
renders machineconfigs. Also applicable post-bootstrap via TalosHardeningApply.
Key spec fields: machineConfigPatches, sysctlParams, description.

---

### TalosHardeningApply

Scope: Namespaced — tenant-{cluster-name}
Short name: tha
Named runner capability: hardening-apply

Post-bootstrap hardening application. CAPI has no equivalent.
Key spec fields: clusterRef, hardeningProfileRef, applyStrategy.

---

### TalosNodePatch

Scope: Namespaced — tenant-{cluster-name}
Short name: tnp
Named runner capability: node-patch

Targeted machine config patch to specific nodes. CAPI's upgrade model replaces
machines rather than patching in place — for ONT's bare-metal and VM model, in-place
patching is the correct approach and has no CAPI equivalent.
Key spec fields: clusterRef, targetNodes, patchSecretRef, mode.

---

### TalosNoMaintenance

Scope: Namespaced — tenant-{cluster-name}
Short name: tnm

Maintenance window gate. Integrates with CAPI's pause mechanism — when no active
window exists and blockOutsideWindows is true, the TalosCluster reconciler sets
cluster.x-k8s.io/paused=true on the CAPI Cluster object. This halts all CAPI
reconciliation until the window opens and the pause is lifted.
Key spec fields: clusterRef, windows, blockOutsideWindows.

---

### TalosClusterReset

Scope: Namespaced — tenant-{cluster-name}
Short name: tcr
Named runner capability: cluster-reset

Destructive factory reset. Human gate required. The reset sequence now includes
deleting the CAPI Cluster object (and all its owned children) before calling
Talos reset API on nodes. CAPI deletion triggers machine deprovisioning through
the ONT Infrastructure Provider — nodes are cleanly removed from the CAPI
inventory before the OS is reset.

Requires ontai.dev/reset-approved=true annotation. Gate unchanged.
Key spec fields: clusterRef, drainGracePeriodSeconds, wipeDisks.

---

### TalosCredentialRotation

Scope: Namespaced — tenant-{cluster-name}
Short name: tcrr
Named runner capability: credential-rotate

Key spec fields: clusterRef, rotateServiceAccountKeys, rotateOIDCCredentials.

---

## 6. CRDs Delegated to CAPI for Target Clusters

These CRDs follow a dual path determined by TalosCluster spec.capi.enabled:
- When spec.capi.enabled=true (all target clusters): CAPI handles this operation
  natively and no ONT CRD is created for that cluster. CAPI controllers drive the
  operation through native CAPI object mutations.
- When spec.capi.enabled=false (management cluster): this CRD is fully retained and
  submits a direct runner Job via OperationalJobReconciler, identical in pattern to
  TalosBackup and TalosPKIRotation.

**TalosUpgrade**
Named runner capability: talos-upgrade
CAPI path (capi.enabled=true): CAPI MachineDeployment rolling upgrade handles Talos
OS version upgrades natively. The TalosConfigTemplate is updated with the new Talos
installer image reference; CAPI's rolling upgrade machinery replaces machines one by one.
Direct runner path (capi.enabled=false): submits a talos-upgrade executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

**TalosKubeUpgrade**
Named runner capability: kube-upgrade
CAPI path (capi.enabled=true): TalosControlPlane version field update handled natively
by CABPT through the control plane provider.
Direct runner path (capi.enabled=false): submits a kube-upgrade executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

**TalosStackUpgrade**
Named runner capability: stack-upgrade
CAPI path (capi.enabled=true): coordinated TalosControlPlane and MachineDeployment
version field updates following CAPI upgrade conventions.
Direct runner path (capi.enabled=false): submits a stack-upgrade executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

**TalosNodeScaleUp**
Named runner capability: node-scale-up
CAPI path (capi.enabled=true): increasing MachineDeployment replicas; the ONT
Infrastructure Provider delivers machineconfig to the new ONTInfrastructureMachine
objects as they are claimed by the new Machine objects.
Direct runner path (capi.enabled=false): submits a node-scale-up executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

**TalosNodeDecommission**
Named runner capability: node-decommission
CAPI path (capi.enabled=true): decreasing MachineDeployment replicas or deleting a
specific Machine object; CAPI handles cordon, drain, and machine deletion natively.
Direct runner path (capi.enabled=false): submits a node-decommission executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

**TalosReboot**
Named runner capability: node-reboot
CAPI path (capi.enabled=true): Machine annotation-based reboot triggers following
CAPI conventions; the ONT Infrastructure Provider detects the annotation and calls
the Talos reboot API.
Direct runner path (capi.enabled=false): submits a node-reboot executor Job via
OperationalJobReconciler. Active when TalosCluster spec.capi.enabled=false only.

---

## 7. Tenant Coordination CRDs — Unchanged

### PlatformTenant, ClusterAssignment, QueueProfile, LicenseKey

These CRDs are unchanged. Their semantics, namespace placement, and gate conditions
are identical to the previous schema. ClusterAssignment now additionally gates on
CAPI Cluster status.phase=Running before the Cilium ClusterPack PackExecution is
triggered via bootstrapFlag.

QueueProfile is scoped to ont-infra's quota profile only. The ClusterQueue and
ResourceFlavor resources provisioned by ont-security from QueueProfile govern
pack-deploy Job admission — cluster lifecycle operations no longer go through Kueue.

---

## 8. Kueue Scope

Kueue remains a management cluster prerequisite exclusively because ont-infra's
pack-deploy Jobs require it. The ClusterQueue and ResourceFlavor resources
provisioned by ont-security from QueueProfile govern pack-deploy Job admission.

Cluster lifecycle operations (bootstrap, upgrade, scale, decommission) do not use
Kueue. They are reconciled by CAPI controllers directly. The observability
previously provided by Kueue Jobs is now provided by CAPI Cluster and Machine
status conditions and events.

Operational Jobs (etcd-backup, etcd-maintenance, pki-rotate, etcd-restore,
hardening-apply, node-patch, credential-rotate, cluster-reset) submit directly to
the default JobQueue without Kueue admission control. They are targeted, infrequent,
and operator-gated operations that do not require Kueue's quota and scheduling machinery.

---

## 9. CAPI RBAC and ont-security

CAPI installs substantial RBAC: ClusterRoles and ClusterRoleBindings for each
provider controller, ServiceAccounts, and webhook configurations. All of this
must pass through ont-security's third-party RBAC intake protocol before CAPI
controllers start.

The enable phase order is:
1. ont-security (CRD-only phase, webhook operational)
2. cert-manager (RBAC via ont-security intake)
3. Kueue (RBAC via ont-security intake)
4. CNPG (RBAC via ont-security intake, ont-security transitions to phase 2)
5. CAPI core (RBAC via ont-security intake)
6. CABPT (RBAC via ont-security intake)
7. metallb (RBAC via ont-security intake)
8. local-path-provisioner (RBAC via ont-security intake)
9. ont-platform (RBACProfile provisioned by ont-security, then controller starts)
10. ont-infra (RBACProfile provisioned, then controller starts)

No CAPI component starts until ont-security has processed its RBACProfile and
set provisioned=true.

---

## 10. Cross-Domain Rules

Reads: security.ontai.dev/RBACProfile status (gate check).
Reads: infra.ontai.dev/ClusterPack (validate Cilium pack reference in TalosCluster).
Reads: infra.ontai.dev/PackInstance (gate ClusterAssignment on Cilium Ready).
Owns: cluster.x-k8s.io/Cluster and all CAPI child objects for target clusters.
Owns: ONTInfrastructureCluster, ONTInfrastructureMachine in tenant namespaces.
Creates: tenant namespaces — sole authority.
Never writes to security.ontai.dev, infra.ontai.dev, or runner.ontai.dev CRDs.

---

*platform.ontai.dev schema — ont-platform*
*Amendments:*
*2026-03-30 — CAPI adopted for target cluster lifecycle. ONT Infrastructure Provider*
*  introduced. ONTInfrastructureMachine and ONTInfrastructureCluster CRDs added.*
*  TalosUpgrade, TalosKubeUpgrade, TalosStackUpgrade, TalosNodeScaleUp,*
*  TalosNodeDecommission, TalosReboot replaced by CAPI equivalents.*
*  Kueue scoped to ont-infra pack-deploy Jobs only.*
*  TalosNoMaintenance integrated with CAPI pause mechanism.*
*  Cilium CNI integration documented. CiliumPending condition added to TalosCluster.*
*  Management cluster bootstrap unchanged — CAPI not applicable.*

*2026-03-30 — Section 6 retitled "CRDs Delegated to CAPI for Target Clusters"*
*  (Path B ruling). Six lifecycle CRDs are not removed. Dual-path semantics applied:*
*  CAPI-native for spec.capi.enabled=true (target clusters), direct runner Job via*
*  OperationalJobReconciler for spec.capi.enabled=false (management cluster).*
*  Named runner capability references restored for all six entries.*