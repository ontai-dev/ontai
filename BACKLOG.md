# ONT Platform: Backlog

**Last updated:** 2026-05-06 (session/24b -- HardeningProfile bootstrap support: ontai-schema, seam-core type, conditions, CAPI template merge, ONT-native NodeMaintenance flow)

> Before acting on any item here, query the production knowledge graph:
> `/graphify query "<item description>" --graph ~/ontai/graphify-out/graph.json`
> This surfaces the exact files and functions the item touches so you start from ground truth, not stale docs.

---

## Critical

| ID | Component | Description | Graphify query |
|----|-----------|-------------|----------------|
| TCOR-SIZE-BOUND | conductor, platform | `AppendOperationRecord` has no size guard. At 500 bytes/entry, 3000 entries hit the etcd 1.5 MB limit. Fix: add mid-epoch flush in `AppendOperationRecord` when `len(operations) >= 1000`, calling `stubDumpTCORRevisionToGraphQueryDB` without bumping the revision number. The stub exists at `platform/internal/controller/tcor_graphquery_stub.go`. Low risk at current lab scale (fewer than 100 ops/epoch). Unblocked when GraphQuery DB service is available. | `query "AppendOperationRecord TCOR operations limit flush"` |

---

## High Priority

| ID | Component | Description | Graphify query |
|----|-----------|-------------|----------------|
| DAY2-OPS-TENANT | conductor, platform | Remaining live day-2 validation gaps. Blocked on infrastructure: ccs-dev (10.20.0.20) unreachable, ccs-mgmt cp3 NotReady. Once infra recovers: TENANT-HP-CLUSTER, TENANT-HP-NODE, TENANT-PKI-CLUSTER-REACH re-run required. MGMT-HP-NODE blocked on MGMT-HP-NODE-DESIGN decision below. Passed in session/17: MGMT-HP-CLUSTER, MGMT-HP-PROFILE, TENANT-HP-PROFILE, TENANT-PKI-ROTATE. | `query "hardeningApplyHandler TalosCluster e2e"` |
| MGMT-HP-NODE-DESIGN | conductor, platform | `mgmtWorkerNode = "ccs-mgmt-w2"` hardcoded in `platform/test/e2e/day2/hardeningprofile_e2e_test.go` does not exist on ccs-mgmt. Decision required: either update the test to an existing node name, or implement per-target-node filtering in `hardeningApplyHandler` so `TargetNodes` in `NodeMaintenanceSpec` drives which endpoints receive `ApplyConfiguration`. Session/22 fixed the VIP destruction bug (ClusterEndpoint filtering + waitForNodeStable) but did not add per-node selection. | `query "hardeningApplyHandler TargetNodes NodeMaintenanceSpec"` |
| K8S-DRIFT-CONFIRM | platform, conductor | `drift-k8s-version-ccs-dev` DriftSignal was queued in session/18 (nodes were at v1.32.4 after out-of-band upgrade). Corrective `UpgradePolicy` `drift-k8s-version-ccs-dev` exists in `seam-tenant-ccs-dev` targeting kubernetesVersion=1.32.3. UpgradePolicyReconciler must submit a kube-upgrade Job. If keeping 1.32.4 is intentional, update `spec.kubernetesVersion` in TalosCluster and delete the DriftSignal. Either close or confirm. | `query "drift-k8s-version UpgradePolicy kube-upgrade DriftSignalReconciler"` |

---

## Medium Priority

| ID | Component | Description | Graphify query |
|----|-----------|-------------|----------------|
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | No sweep reconciler exists that lists raw RBAC objects (ClusterRole, ClusterRoleBinding, ServiceAccount) arriving in `seam-tenant-*` outside `/rbac-intake/pack` and creates missing RBACProfiles for them. `APIGroupSweepController` (already implemented) handles CRD-level API group discovery for `management-maximum` -- it is a different concern. Design session required before implementation. | `query "RBACProfile sweep seam-tenant raw RBAC objects"` |
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | Webhook validation for seam-operator-labelled RBACProfiles: profiles with the `seam-operator` label must reference `management-maximum` only (never `cluster-maximum`). `RBACProfile` is already in `InterceptedKinds`. This is a new admission rule to add to the webhook handler. Verify live against admission webhook once implemented. | `query "RBACProfile InterceptedKinds webhook seam-operator label"` |
| WRAPPER-BL-ILI-DECLARING-PRINCIPAL | guardian, wrapper | `MutatingWebhookConfiguration` for the `declaring-principal` handler is not present in the compiler enable bundle (`compile_enable.go`). The handler itself was implemented in session/15. The webhook configuration needs to be emitted by the compiler and applied to the cluster. Verify that `SealedCausalChain` immutability webhook covers the ILI rootBinding as intended. | `query "declaring-principal MutatingWebhookConfiguration ILI compiler enable bundle"` |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | `ConductorReady` gate in wrapper uses a 30-second requeue poll rather than a Watch on `RunnerConfig` status. Should watch `RunnerConfig` and trigger immediately when capabilities appear. `isConductorReadyForCluster` in `packexecution_reconciler.go` is the entry point. | `query "isConductorReadyForCluster RunnerConfig watch gate ConductorReady"` |
| G-BL-SNAPSHOT-ALIAS | guardian | `snapshot-management` PermissionSnapshot should extend coverage to include `ccs-mgmt` so the redundant `snapshot-ccs-mgmt` PermissionSnapshot is eliminated. Deduplication reduces operational noise. | `query "snapshot-management PermissionSnapshot ccs-mgmt alias"` |
| G-BL-IDP-POLLING | guardian | `IdentityProviderReconciler` must poll the OIDC provider for group membership changes and update `PermissionSet` bindings accordingly. Requires Keycloak or Dex in lab before live testing. | `query "IdentityProviderReconciler OIDC group membership polling"` |
| G-BL-SELF-AUDIT-MISSING | guardian | `rbac.would_deny` audit event is absent from the admission webhook deny path. Investigation required: locate the deny branch in `guardian/internal/controller/` webhook handler and confirm whether the audit write was omitted or is blocked by another invariant. | `query "rbac.would_deny audit event admission webhook deny path"` |
| SEAM-CORE-BL-DESCENDANT-LABELS | seam-core, guardian | `PermissionSnapshot` lineage wiring to `InfrastructureLineageIndex` deferred. Governor ruling required on whether there is one root `RBACPolicy` per snapshot or one per operator. Cannot proceed without that decision. | `query "PermissionSnapshot lineage InfrastructureLineageIndex rootBinding"` |
| WRAPPER-BL-ENVTEST-GC | wrapper | `TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted` requires kube-controller-manager GC, which envtest does not provide (envtest runs etcd + kube-apiserver only). Must be promoted to a live cluster e2e spec once ccs-dev is reachable. | `query "TestPackInstance OwnerRefCascade PackExecution cascade delete"` |

---

## Not Yet Tested (Live Cluster Required)

| Area | Component | Blocker | Graphify query |
|------|-----------|---------|----------------|
| HardeningProfile TENANT | platform, conductor | ccs-dev unreachable; MGMT-HP-NODE also needs design decision | `query "hardeningApplyHandler TENANT e2e cluster"` |
| PKI rotation TENANT reach | platform, conductor | ccs-dev unreachable; pack-deploy Job cannot connect | `query "pkiRotationHandler TENANT e2e PackExecution"` |
| Federation audit channel | conductor | Implemented in session/15; never tested live. Audit forwarding from tenant conductor to management guardian. | `query "federation audit channel TLS WAL"` |
| CAPI cluster lifecycle | platform | `SeamInfrastructureCluster` and `SeamInfrastructureMachine` full lifecycle. Unit tests exist. No e2e scheduled. | `query "SeamInfrastructureCluster SeamInfrastructureMachine lifecycle e2e"` |
| IdentityBinding live | guardian | No Keycloak or Dex provisioned in lab. Cannot test OIDC flow. | `query "IdentityBinding IdentityProvider OIDC live"` |
| SeamMembership live | seam-core, guardian | Compiler emits SeamMembership CRs in phase 01. Never verified on lab. | `query "SeamMembership compiler phase01 live"` |
| ClusterReset live | platform | Requires `ontai.dev/reset-approved=true` annotation. Deliberately untested to avoid cluster destruction. | `query "ClusterReset reset-approved TalosClusterReset"` |

---

## Roadmap (Future -- Post-Alpha)

| ID | Description | Graphify query |
|----|-------------|----------------|
| VORTEX-CLI | `ont history`, `ont graph`, `ont delta` commands against Guardian-authorized audit sink. Specification in `docs/playbooks/vortex-retrieval-interface.md`. Not started. | `query "Vortex retrieval interface audit sink"` |
| APP-CORE | Scaffold app-core with 9 CRDs under `core.ontai.dev`. Required before Vortex SeamMembership integration. Domain-core Layer 0 is complete. | `query "app-core CRD core.ontai.dev SeamMembership"` |
| DOCUMENTATION-CLUSTER | Sovereign cluster for unified cross-domain lineage graph. Follows Vortex retrieval interface. No design yet. | `query "documentation cluster lineage graph sovereign"` |
| ONTAR-SPEC | Formalize PermissionSnapshot pod contract schema in `seam-core/docs/ontar-spec.md`. After alpha release and first production fintech operator adoption. | `query "ONTAR PermissionSnapshot pod contract schema"` |
| SCREEN | VirtCluster and VirtMachine CRDs. CAPI path to QEMU/KVM via libvirt and KubeVirt. INV-021: no implementation until Governor-approved ADR. | `query "Screen VirtCluster VirtMachine QEMU KubeVirt"` |
| SERVICEMONITOR | Prometheus ServiceMonitor CRDs for all five operators. Deferred to post-e2e observability session. | `query "ServiceMonitor Prometheus operator observability"` |
| CAPI-E2E | e2e tests for `SeamInfrastructureCluster`/`Machine` full lifecycle against live cluster. | `query "CAPI e2e SeamInfrastructureCluster lifecycle test"` |

---

## Closed

| ID | Component | Closed | Resolution |
|----|-----------|--------|------------|
| PLATFORM-BL-HARDENINGPROFILE-MERGE | platform, seam-core | 2026-05-06 | `hardeningProfileRef` added to `InfrastructureTalosClusterSpec` (schema + seam-core type). CAPI path: `ensureTalosConfigTemplate` merges `MachineConfigPatches` + `SysctlParams` into `TalosConfigTemplate` at provisioning; sets `HardeningApplied=True`. ONT-native path: `ensureBootstrapHardening` creates `NodeMaintenance` (operation=hardening-apply, label `ontai.dev/hardening-trigger=bootstrap`) in `seam-tenant-{cluster}` post-Ready; sets `HardeningApplied=True` when `NodeMaintenance` reaches `Ready=True`. `ConditionTypeHardeningApplied` added to seam-core/pkg/conditions. 4 unit tests pass. |
| PLATFORM-BL-MACHINECONFIG-BACKUP | platform, conductor | 2026-05-06 | `machineconfig-backup` conductor capability implemented. Iterates nodes via `EndpointsFromTalosconfig` + `NodeContext`, calls `GetMachineConfig` per node, uploads to S3 at `{cluster}/machineconfigs/{TIMESTAMP}/{hostname}.yaml`. `TalosMachineConfigBackup` CRD added to platform API. `MachineConfigBackupReconciler` registered. 5 unit tests pass. `machineconfig-restore` deferred to next session (restore capability + `TalosMachineConfigRestore` CRD). |
| PLATFORM-BL-TALOSCONFIG-ONTYSYSTEM-REMOVE | platform | 2026-05-06 | Removed `ont-system` from `ensureExecutorTalosconfig` loop (`taloscluster_helpers.go`). Day-2 Jobs run in `seam-tenant-{cluster}` and mount from that namespace. ont-system copy was unused. |
| PLATFORM-BL-KUBECONFIG-CANONICAL | platform, conductor | 2026-05-06 | Removed `tenantKubeconfigSecretName` constant and `ensureTenantKubeconfigCopy` from `taloscluster_import_helpers.go`. Added `ensureCAPIKubeconfig` and `ensureCAPITalosconfig` helpers. `EnsureRemoteConductorBootstrap` now always reads `seam-mc-{cluster}-kubeconfig`. `platform_security.go` no longer writes `target-cluster-kubeconfig`. e2e test updated. |
| PLATFORM-BL-CAPI-TENANT-ONBOARDING | platform | 2026-05-06 | Added step 8.5 to `reconcileCAPIPath`: calls `ensureCAPITalosconfig`, `ensureCAPIKubeconfig`, `ensureTenantOnboarding` before `ensureConductorReadyAndTransition`. CAPI clusters now receive full tenant onboarding on reaching Running state. |
| T-23 | platform | 2026-05-05 | `DriftSignalReconciler` implemented at `platform/internal/controller/driftsignal_reconciler.go`. Handles RunnerConfig drift, Talos version drift, K8s version drift. Live verified session/17-18. |
| T-24 | platform | 2026-05-05 | Decision H deletion cascade implemented. `finalizerDecisionHCascade` in `taloscluster_helpers.go`. `handleTalosClusterDeletion` enforces wrapper-first, then guardian, then TalosCluster teardown order. |
| GUARDIAN-AUTO-RBAC | guardian | 2026-05-05 | `APIGroupSweepController` at `guardian/internal/controller/apigroup_sweep_controller.go`. Watches CRDs, extends `management-maximum` PermissionSet with rules for every third-party API group. |
| COMPILER-BL-HARDENINGAPPLY-VIP | conductor | 2026-05-05 (session/22) | `EndpointsFromTalosconfig` now filters `clusterEndpoint` VIP. `waitForNodeStable` added between node iterations. 3 new passing tests. PR #37 merged. |
| COMPILER-BL-PERMISSIONSET-DEFECT | conductor | 2026-04-26 | `writeBootstrapPermissionSets` emits only `management-maximum`. Both enable bundles regenerated. |
| DAY2-ETCD-S3-LIVE | conductor, platform | 2026-05-02 | Etcd backup and restore Jobs validated live on ccs-dev (session/17 Task C). |
| CLUSTERPACK-BL-VERSION-CLEANUP | conductor | 2026-05-02 | `deleteOrphanedResources()` + `deployedResourceKey()` in `packinstance_pull_loop.go`. 2 unit tests. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor | 2026-05-02 | `RBACProfilePullLoop` in `rbacprofile_pull_loop.go`. 4 unit tests. |
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | platform | 2026-05-02 | `finalizerWrapperRunnerCRBCleanup` + Step 3 in `handleTalosClusterDeletion`. |
| TENANT-CLUSTER-E2E | all | 2026-05-01 | Full ccs-dev lifecycle validated. |
| CONDUCTOR-BL-DRIFT-SIGNAL | conductor | 2026-05-01 | `PackReceiptDriftLoop` + `DriftSignalHandler`. 14 unit tests. |
| GUARDIAN-BL-PERMISSIONSET-WATCH | guardian | 2026-04-26 | `Watches(PermissionSet, MapPermissionSetToProfiles)` added. 5 unit tests. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | 2026-04-26 | GVK correct post-Phase 2B. 4 unit tests. |
| PLATFORM-BL-3-LOCALQUEUE | platform | 2026-04-26 | `ensureTenantOnboarding` creates LocalQueue. Unit test added. |
| GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING | guardian | 2026-05-01 | `reconcileTenantSnapshotPath()` in `RBACProfileReconciler`. |
| CONDUCTOR-BL-SIGNING-KEY-TENANT | conductor | 2026-05-01 | `--signing-private-key` rejected for `--cluster-role=tenant`. |
