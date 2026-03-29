# ont-platform-schema
> API Group: platform.ontai.dev
> Operator: ont-platform
> Absorb before any design or implementation work in this domain.

---

## 1. Domain Boundary

ont-platform owns the complete lifecycle of Talos clusters and all tenant coordination.

ont-platform is a thin reconciler. Its pattern for every CR is: watch → read RunnerConfig → confirm named capability → build Job spec → submit to Kueue → read OperationResult → update CR status. No execution logic lives here.

ont-platform creates tenant namespaces. It is the sole namespace creation authority for tenant namespaces. It generates RunnerConfig for every cluster it manages using the shared runner library imported from ont-runner.

---

## 2. CRDs

### TalosCluster

Scope: Namespaced — ont-system for the management cluster, tenant-{name} for target clusters.
Short name: tc
Lives in: git (human-authored or runner compile-validated) and management cluster.

The single cluster lifecycle CR. 
The runner compile mode validates it and generates associated secrets (talos-secret, machineconfigs, talosconfig — SOPS-encrypted in git). On GitOps apply, TalosCluster lands on the management cluster. ont-platform generates RunnerConfig from it and submits the bootstrap capability Job.

Key spec fields:
- clusterEndpoint: VIP or first control plane IP. Embedded in all generated configs.
- talosVersion: Talos OS version. Determines installer image and runner compatibility.
- kubernetesVersion: Kubernetes version to pin.
- installDisk: block device path for Talos installation.
- controlPlane.nodes: list of control plane node IPs.
- workers.nodes: list of worker node IPs. May be empty.
- seedNodes: node IPs reachable on port 50000 before config is applied.
- hardeningProfileRef: optional TalosHardeningProfile reference.
- s3Prefix: S3 path prefix for backup artifacts.
- hypervisorRef: optional KVM host reference for VM-based clusters.

All machineconfig customization is human-authored at compile time as files alongside TalosCluster in git. The runner absorbs them into secrets. No machineconfig patch fields exist on TalosCluster — customization is a compile-time human responsibility, not a runtime CRD field.

Status conditions: Ready, Bootstrapping, Degraded.

Generated secrets written to ont-system by runner executor:
- talosconfig-{name}: Talos client config and CA.
- kubeconfig-{name}: Kubernetes admin kubeconfig (generated at runtime, not in git).
- machineconfig-{name}: control plane and worker configs as data keys.

Invariant: TalosCluster deletion never triggers physical cluster destruction.
TalosClusterReset is the only path to cluster destruction. INV-015.

---

### TalosUpgrade

Scope: Namespaced — tenant-{cluster-name}
Short name: tu
Named capability: talos-upgrade

Upgrades Talos OS version on all nodes. Rolling: control plane first, then workers.
Each node is cordoned, upgraded, and uncordoned before the next begins.

Key spec fields: clusterRef, targetVersion, maintenanceWindowRef.

The operator observes current Talos version exclusively through Kubernetes node
labels populated by Talos machined. No talos goclient access in the operator.
Only the runner speaks to the Talos API. INV-013.

---

### TalosKubeUpgrade

Scope: Namespaced — tenant-{cluster-name}
Short name: tku
Named capability: kube-upgrade

Upgrades Kubernetes version independently of Talos OS version.
Key spec fields: clusterRef, targetVersion.

---

### TalosStackUpgrade

Scope: Namespaced — tenant-{cluster-name}
Short name: tsu
Named capability: stack-upgrade

Coordinated Talos OS and Kubernetes upgrade in a single Job. The runner owns the
sequence internally: OS upgrade completes cluster-wide, cluster health verified,
then Kubernetes upgrade proceeds. One Job submitted, one OperationResult produced.

Key spec fields: clusterRef, targetTalosVersion, targetKubernetesVersion.

---

### TalosBackup

Scope: Namespaced — tenant-{cluster-name}
Short name: tb
Named capability: etcd-backup

etcd snapshot and machine config export to S3. Supports one-shot and cron schedule.
Key spec fields: clusterRef, schedule, s3Destination, includeEtcd, includeMachineConfig.

---

### TalosHardeningProfile

Scope: Namespaced
Short name: thp

Reusable collection of machine config patches and sysctl parameters. Referenced
by TalosCluster at compile time and by TalosHardeningApply post-bootstrap.

Key spec fields: machineConfigPatches, sysctlParams, description.

---

### TalosHardeningApply

Scope: Namespaced — tenant-{cluster-name}
Short name: tha
Named capability: hardening-apply

Applies a TalosHardeningProfile to a running cluster.
Key spec fields: clusterRef, hardeningProfileRef, applyStrategy.

---

### TalosPKIRotation

Scope: Namespaced — tenant-{cluster-name}
Short name: tpr
Named capability: pki-rotate

Rotates PKI certificates. Updates talosconfig secret in ont-system after rotation.
Key spec fields: clusterRef.

---

### TalosNodePatch

Scope: Namespaced — tenant-{cluster-name}
Short name: tnp
Named capability: node-patch

Applies a machine config patch to one or more nodes. Changes are recorded in
RunnerConfig operational history.
Key spec fields: clusterRef, targetNodes, patchSecretRef, mode (try or apply).

---

### TalosEtcdMaintenance

Scope: Namespaced — tenant-{cluster-name}
Short name: tem
Named capability: etcd-maintenance

etcd defragmentation and optional snapshot.
Key spec fields: clusterRef, defrag, snapshot.

---

### TalosNodeScaleUp

Scope: Namespaced — tenant-{cluster-name}
Short name: tnsu
Named capability: node-scale-up

Provisions and bootstraps additional nodes into an existing cluster.
Key spec fields: clusterRef, newNodes, nodeRole.

---

### TalosNoMaintenance

Scope: Namespaced — tenant-{cluster-name}
Short name: tnm

Maintenance window gate. Upgrade and patch operations check for an active window
before proceeding when this CR is present.
Key spec fields: clusterRef, windows, blockOutsideWindows.

---

### TalosNodeDecommission

Scope: Namespaced — tenant-{cluster-name}
Short name: tnd
Named capability: node-decommission

Cordons, drains, removes node from Kubernetes and Talos.
Key spec fields: clusterRef, nodeIP, drainGracePeriodSeconds.

---

### TalosReboot

Scope: Namespaced — tenant-{cluster-name}
Short name: tr
Named capability: node-reboot

Reboots one or all nodes. Rolling or simultaneous.
Key spec fields: clusterRef, targetNodes, mode.

---

### TalosCredentialRotation

Scope: Namespaced — tenant-{cluster-name}
Short name: tcrr
Named capability: credential-rotate

Rotates service account signing keys and OIDC credentials.
Key spec fields: clusterRef, rotateServiceAccountKeys, rotateOIDCCredentials.

---

### TalosRecovery

Scope: Namespaced — tenant-{cluster-name}
Short name: trec
Named capability: etcd-restore

Disaster recovery from S3 etcd snapshot.
Key spec fields: clusterRef, s3SnapshotPath, targetNodes.

---

### TalosClusterReset

Scope: Namespaced — tenant-{cluster-name}
Short name: tcr
Named capability: cluster-reset

Destructive factory reset. Human gate: reconciler holds at PendingApproval until
annotation ontai.dev/reset-approved=true is present. Set only by ont-runner compile
mode after interactive cluster name confirmation.

Execution sequence (runner executor handles entirely):
1. Cordon all nodes.
2. Drain workloads.
3. Remove ONT resources from target cluster.
4. Remove PackReceipt and PermissionSnapshotReceipt.
5. Delete all operational CRDs from tenant namespace.
6. Call Talos reset API on all nodes.
7. Delete TalosCluster from tenant namespace.
8. Mark historical record in ont-system.

TalosCluster in ont-system is never auto-deleted — it remains as a historical
record. INV-015.
Key spec fields: clusterRef, drainGracePeriodSeconds, wipeDisks.

---

### PlatformTenant

Scope: Namespaced — platform-system
Short name: pt

Permanent identity record for a tenant. Owns ClusterAssignment via ownerReference.
Suspension propagates as annotation to all owned ClusterAssignments.
Key spec fields: customerID, tier, licenseRef, oidcGroup, adminEmail, suspended.
Status conditions: Active, Suspended, LicenseExpired.

---

### ClusterAssignment

Scope: Namespaced — tenant-{cluster-name}
Short name: ca

Binds a tenant to a cluster. References — never owns — resources across all
operator domains. Deleting a ClusterAssignment removes only the binding record.
Never triggers cluster destruction, pack deletion, or RBAC removal. INV-005.

Key spec fields: tenantRef, clusterRef (TalosCluster name), clusterPackRef,
rbacProfileRef, admissionProfileRef, bootstrapFlag, oidcConfig.

Gates before Ready: TalosCluster.status.ready=true, RBACProfile.status.provisioned=true,
ClusterPack registered and not revoked, LicenseKey valid.

---

### QueueProfile

Scope: Namespaced — platform-system
Short name: qp

Kueue quota declaration per licensing tier. ont-security reads it to provision
Kueue ClusterQueue and ResourceFlavor resources. QueueProfile stays in
platform.ontai.dev — quota intent is a platform declaration. The Kueue resources
that result are written by ont-security.
Key spec fields: tier, cpu, memory, maxJobs, borrowingLimit, preemptionPolicy.

---

### LicenseKey

Scope: Namespaced — platform-system
Short name: lk

Wraps a license JWT stored as a Kubernetes Secret. Validates tier, expiry, cluster
count. Referenced by PlatformTenant.
Key spec fields: secretRef, tier, maxClusters.
Status conditions: Valid, Expired, Invalid.

---

## 3. Cross-Domain Rules

Reads: security.ontai.dev/RBACProfile status (gate check only).
Reads: infra.ontai.dev/ClusterPack (validate reference in ClusterAssignment).
Reads: runner.ontai.dev/RunnerConfig status (capability confirmation before Job).
Writes: runner.ontai.dev/RunnerConfig (generates it from TalosCluster spec).
Creates: tenant namespaces — sole authority.
Never writes to any other operator's CRDs.

---

*platform.ontai.dev schema — ont-platform*
*Amendments appended below with date and rationale.*