# ONT Platform Progress

**Last updated:** May 1, 2026 (session/15 TENANT-CLUSTER-E2E + CONDUCTOR-BL-DRIFT-SIGNAL closed)

**Current state:** Full drift detection and circuit breaker loop verified end-to-end. PackReceipt signature verification passes (Ed25519). Conductor role=tenant detects missing Deployment and emits DriftSignal to management cluster. Management conductor handler retriggeres (deletes PackExecution, wrapper creates new one, pack-deploy restores nginx). Three-cycle escalation counter confirmed. TerminalDrift condition set at escalationThreshold=3 with no further retriggering. TENANT-CLUSTER-E2E and CONDUCTOR-BL-DRIFT-SIGNAL closed. Next: CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION, PR series.

**Full history:** PROGRESS-archive-2026-04-20.md

---

## Completed Work

### Phase 2B -- Seam-core CRD Migration (2026-04-25)

Seven infrastructure types migrated from conductor and wrapper into seam-core under `infrastructure.ontai.dev/v1alpha1`. Four ontai-schema PRs (#4-#7) merged. seam-core Go types, conductor, wrapper, and platform import migrations merged. CRD manifests consolidated to seam-core. Enable bundles regenerated for ccs-mgmt and ccs-dev.

### Three-layer RBAC Hierarchy (2026-04-26)

guardian-schema.md §19 replaced with three-layer structural specification (CS-INV-008, CS-INV-009 in guardian/CLAUDE.md). guardian-schema.md §20 added for import-mode tenant onboarding sequencing. Exactly two canonical PermissionSet names: `management-maximum` (Layer 1) and `cluster-maximum` (Layer 2). Known compiler defect tracked as COMPILER-BL-PERMISSIONSET-DEFECT: per-operator PermissionSets still emitted; RBACProfile permissionSetRef still uses `{op.Name}-permissions`.

### TCOR Per-Cluster Accumulator (2026-04-26)

One TCOR per cluster. Operations stored as `map[string]TalosClusterOperationRecord` keyed by Job name. `bumpTCORRevision` fires on talosVersion upgrade. All day-2 reconciler tests updated.

### Conductor-Execute Image Split (2026-04-26)

Executor Jobs use `conductor-execute:dev`. Conductor agent Deployment uses `conductor:dev`. Two-image distinction enforced per Decision 12.

### Management Cluster RBAC Audit (2026-04-26)

Four RBAC gaps found in `compile_enable.go` and fixed (conductor commits `136c42e`, `9e85d88` on `session/15-rbac-gaps`, push confirmed):

| Gap | Fix |
|-----|-----|
| `events.k8s.io/events` missing from all five PermissionSets and `guardian-manager-role` | Added to `writeBootstrapPermissionSets` and `operatorClusterRules` common block |
| `serviceaccounts` missing from `platform-permissions` | Added allVerbs rule |
| `configmaps` missing from `seam-core-permissions` | Added allVerbs rule |
| `infrastructuretalosclusters/status` missing from `conductor-permissions` | Added get/update/patch rule |

Guardian admission webhook running with `failurePolicy: Fail` (confirmed session/15 Round 1). All five `seam:*` ClusterRoles auto-updated by guardian reconciler after enable bundle apply -- no manual patching required (GUARDIAN-BL-PERMISSIONSET-WATCH closed). Enable bundle regenerated and applied; committed to ontai root (`0ec966e`). All operator pods Running clean.

---

## Management Cluster Validation (ccs-mgmt)

Management cluster treated as a tenant for pack delivery (`seam-tenant-ccs-mgmt` namespace).

| # | Test | Status | Notes |
|---|------|--------|-------|
| 1 | Initial pack deploy (nginx v4.9.0-r1): 6-step split path, RBACProfile provisioned=true, PackExecution Succeeded | PASS | session/13 |
| 2 | PackOperationResult created with upgradeDirection=Initial | PASS | session/13 |
| 3 | Pack upgrade (v4.9.0-r1 to v4.10.0-r1): upgradeDirection=Upgrade | PASS | session/13 |
| 4 | Pack rollback (v4.10.0-r1 to v4.9.0-r1): upgradeDirection=Rollback | PASS | session/13 |
| 5 | Pack redeploy (same version): upgradeDirection=Redeploy | PASS | session/13 |
| 6 | ValuesFile field recorded in ClusterPack CR spec | PASS | session/14 |
| 7 | Pack upgrade N→N+1 single-active-revision: r2 created, r1 deleted, one POR survives | PASS | session/14 |
| 8 | PE deletion cascades POR via GC (ownerRef Kind fix) | PASS | session/14 |
| 9 | ClusterPack redeploy after PE+POR deletion starts at r1 | PASS | session/14 |
| 10 | EtcdMaintenance defrag: Running=True then Ready=True | PASS | session/phase2b |
| 11 | ClusterMaintenance window: WindowActive=False (outside window) | PASS | session/phase2b |
| 12 | NodeOperation reboot: JobName set, capability Succeeded | PASS | session/phase2b |
| 13 | NodeMaintenance node-patch: capability fails on absent patchSecretRef (correct validation) | PASS | session/phase2b |
| 14 | PKIRotation end-to-end: TCOR Succeeded; GetMachineConfig+staged apply | PASS | session/14 |
| 15 | UpgradePolicy via spec.versionUpgrade: UpgradePolicy auto-created, VersionUpgradePending=True | PASS | session/phase2b |
| 16 | Machine config capture: seam-mc-{cluster}-{hostname} Secret written after node-patch | IMPL | session/14; full e2e blocked on patchSecretRef |

**ClusterPack reconciler retrigger:** After manual PE deletion, annotate the ClusterPack with `ontai.dev/retrigger=$(date +%s)` to force re-reconciliation.

---

## Session/15 Round 1 Closures (2026-04-26)

| Item | Resolution | Reference |
|------|-----------|-----------|
| GUARDIAN-BL-PERMISSIONSET-WATCH | Watches(PermissionSet, MapPermissionSetToProfiles) added to RBACProfileReconciler.SetupWithManager. 5 unit tests. | guardian session/15-guardian-fixes commit 1881ccf |
| COMPILER-BL-PERMISSIONSET-DEFECT | writeBootstrapPermissionSets emits only management-maximum. buildOperatorRBACProfile uses permissionSetRef: management-maximum. Both enable bundles regenerated. | conductor PR #26 merged |
| Enable bundle applied to ccs-mgmt | All 5 seam:* ClusterRoles auto-updated by guardian reconciler (no manual patching). 5 old per-operator PermissionSets deleted. | ontai root commit f732730 |
| Guardian admission webhook | failurePolicy: Fail confirmed throughout. Test RBACProfile admitted and provisioned clean. | live cluster verified |

---

## Session/15 Round 2 Closures (2026-04-26)

| Item | Resolution | Reference |
|------|-----------|-----------|
| WRAPPER-BL-PACKINSTANCE-WATCH | Phase 2B GVK confirmed correct (InfrastructurePackInstance). MapPackInstanceToClusterPack exported; 4 unit tests added covering cascade delete and namespace guard. | wrapper session/15-wrapper-fixes commit 480fb19 |
| WRAPPER-BL-PACKINSTANCE-VERSION-DOUBLE-V | Verified post-Phase 2B: version comes directly from ClusterPackRef.Version with no extra prefix. Existing test covers. Closed without code change. | packinstance_reconciler.go line 154 |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | RetryOnConflict already implemented in taloscluster_controller.go deferred status patch (line 112, PLATFORM-BL-STATUS-PATCH-CONFLICT comment). Closed without code change. | taloscluster_controller.go line 107-130 |

---

## Session/15 Round 5 Closures (2026-04-26)

| Item | Resolution | Reference |
|------|-----------|-----------|
| T-19 (platform import conductor state machine) | `EnsureConductorDeploymentOnTargetCluster` extended for import mode (reads `target-cluster-kubeconfig`, creates `ont-system` + conductor SA before Deployment). `reconcileDirectBootstrap` tenant path sets Bootstrapped=True then gates Ready on ConductorReady. Management import unchanged. `transitionToReady` no longer sets Origin; each path sets it explicitly. 4 new unit tests. | platform PR #17 |
| T-19a (guardian conductor-tenant RBACProfile) | `ClusterRBACPolicyReconciler.reconcileCreate` creates `conductor-tenant` RBACProfile in `seam-tenant-{cluster}` for role=tenant TalosClusters. `reconcileDelete` explicitly deletes it. `LabelValuePolicyTypeSeamOperator` added; backfill sweep ignores it. `guardian-schema.md §20` added (full handshake protocol). 3 new unit tests. | guardian PR #18 |

---

## Session/15 Import-Wiring Correction (2026-04-26)

| Item | Resolution | Reference |
|------|-----------|-----------|
| Option B revert | session/15-import-wiring changes reverted. Compiler emits seam-tenant-namespace.yaml for mode=import (both compileBootstrap and compileImportTalosconfigSecret). Platform controller import block ordering restored: ensureKubeconfigSecret before ensureTenantNamespace. platform-schema.md §9 namespace authority section corrected. | conductor 66c875e, platform d2c49db |

---

## Session/15 Import-Wiring Closures (2026-04-26)

| Item | Resolution | Reference |
|------|-----------|-----------|
| CP-INV-004 wiring (namespace creation authority) | Compiler no longer emits seam-tenant namespace manifest for any mode. `writeSeamTenantNamespaceManifest` function removed from compile.go. `compileBootstrap` importExistingCluster block and `compileImportTalosconfigSecret` both updated. platform-schema.md §9 rewritten to document mode-specific machineconfig/namespace provisioning. | conductor session/15-import-wiring |
| Import circular dependency fix (namespace before kubeconfig) | `reconcileDirectBootstrap` in taloscluster_controller.go now calls `ensureTenantNamespace` for role=tenant BEFORE `ensureKubeconfigSecret`. Eliminates chicken-and-egg: talosconfig Secret lives in seam-tenant-{cluster}; namespace must exist before the Secret is read. | platform session/15-import-wiring |
| Bootstrap-sequence step descriptions updated | writeBootstrapSequence mode=import step descriptions now document that Secrets live in seam-tenant-{cluster}, that CP-INV-004 governs namespace creation, and that role=tenant clusters must apply TalosCluster CR before the talosconfig Secret. | conductor session/15-import-wiring |
| Compiler tests updated | TestBootstrap_ImportMode_EmitsSeamTenantNamespaceManifest replaced by TestBootstrap_ImportMode_DoesNotEmitSeamTenantNamespaceManifest. TestBootstrap_ImportMode_NamespaceNameIsSeamTenantNotTenant removed. TestBootstrap_ImportExistingCluster_LocalFilePath namespace-file assertion inverted. All 12 compiler tests pass. | conductor session/15-import-wiring |
| Platform unit tests verified | All platform unit tests pass after namespace ordering change (T-19 import tests: TestTenantImport_ConductorPending, TestTenantImport_ConductorReady, TestTalosClusterReconcile_TenantImport_CreatesLocalQueue). | platform session/15-import-wiring |
| BACKLOG updated | PLATFORM-BL-MACHINECONFIG-IMPORT-CAPTURE added. PLATFORM-BL-HARDENINGPROFILE-MERGE updated to note it also blocks bootstrap machineconfig generation from spec. | BACKLOG.md |

---

## Session/15 Live Tenant Onboarding (2026-04-30)

### Architecture Clarifications (locked this session)

- **No RunnerConfig on tenant clusters.** RunnerConfig is management-only for day2 ops and ClusterPack delivery. Conductor role=tenant has no RunnerConfig.
- **Capability publisher is role=management only.** Conductor role=tenant skips capability publication entirely.
- **Platform bootstrap window scope (INV-020).** Platform's sole responsibility for any InfrastructureTalosCluster (role=tenant, mode=import or mode=bootstrap): `ont-system` namespace + conductor ServiceAccount + ClusterRole/ClusterRoleBinding + InfrastructureTalosCluster CR copy. No Deployment creation. Enable bundle is the sole conductor Deployment authority for all cluster roles.
- **Conductor role=tenant responsibilities.** Watches InfrastructureTalosCluster (copy in ont-system) and PackReceipts. Detects drift vs live deployed resources by comparing PackReceipt declared digests against actual tenant cluster resources. PackReceipt is the sole local reference for desired state -- no mirror CRDs are created (Decision D revised 2026-04-30; T-18 closed obsolete). Signals conductor role=management on drift via federation channel. Drift retrigger: max 3 attempts. On 3rd failure: records drift reason in ClusterPack status on both management and tenant clusters. No remediation without management cluster confirmation.
- **Full pack delivery chain (locked 2026-04-30).** Compiler pushes OCI artifact to registry. ClusterPack CR admitted on management cluster. Wrapper creates PackExecution. Management conductor signing loop signs PackExecution. Wrapper PackExecutionReconciler runs four-gate check; on all gates passing, creates Kueue Job in seam-tenant-{clusterName}. Conductor-execute Job (runs on management cluster, uses kubeconfig in seam-tenant-{clusterName}) connects to tenant cluster and applies RBAC layer then cluster-scoped layer then workload layer in order. Conductor-execute writes PackReceipt into ont-system on the tenant cluster and PackInstance into seam-tenant-{clusterName} on the management cluster. Conductor-execute is the only actor that crosses the cluster boundary. T-18 (mirror CRD reconstruction on tenant cluster) is obsolete: PackReceipt carries all information needed for drift detection.
- **ClusterPack version cleanup.** When a new PackInstance version removes components, orphaned resources from the old version must be deleted from the tenant cluster. PackReceipt must carry a full resource inventory (GVK + name + namespace). Conductor role=tenant diffs old PackReceipt inventory vs new PackInstance manifests and deletes orphans. Tracked as CLUSTERPACK-BL-VERSION-CLEANUP.

### Work Completed (2026-04-30)

| Item | Resolution | Reference |
|------|-----------|-----------|
| seam-core conditions rename | `ReasonConductorDeploymentAvailable/Unavailable` → `ReasonConductorBootstrapComplete/Pending`. `ConditionTypeConductorReady` now means bootstrap window complete, not Deployment available. | seam-core main 43e48f3 |
| Platform bootstrap window refactor | `EnsureConductorDeploymentOnTargetCluster` → `EnsureRemoteConductorBootstrap`. Returns (true, nil) when namespace+SA+RBAC+InfrastructureTalosCluster copy done. `BuildConductorAgentDeployment` removed. `RemoteConductorAvailableFn` → `RemoteConductorBootstrapDoneFn`. All tests updated. | platform session/15 f372d57 |
| Conductor ClusterRole conductor-agent-tenant | Added `coordination.k8s.io/leases` (full verbs, leader election) and `rbac.authorization.k8s.io` roles/rolebindings/clusterroles/clusterrolebindings (get/list/watch/update/patch, drift detection + bootstrap sweep). | platform session/15 f372d57 |
| Conductor role-aware enable bundle | Compiler `--cluster-role=tenant` emits phases 00a, 00 (seam-core CRDs), 04 (conductor), 05 (DSNS). Guardian and platform-wrapper phases 01-03 skipped. No seam-tenant namespace in 00a. No RBACProfile in 04. No Kueue resources in 05. | conductor session/15 1708bab |
| Conductor capability publisher gated | `agent.NewCapabilityPublisher` only created when `role == RoleManagement`. `onLeaderStart` nil-guards the call. role=tenant startup produces no RunnerConfig errors. | conductor session/15 1708bab |
| ccs-dev enable bundle applied | Phases 00a, 00, 04, 05 applied to ccs-dev. seam-core CRDs installed. Conductor running clean -- leader elected, bootstrap sweep completing, no forbidden errors. | live cluster |
| InfrastructureTalosCluster copy in ont-system | EnsureRemoteTalosClusterCopy confirmed working: InfrastructureTalosCluster exists in ccs-dev's ont-system, conductor role=tenant watching it. | live cluster |

---

## Session/15 PackReceipt Write Closure (2026-05-01)

| Item | Resolution | Reference |
|------|-----------|-----------|
| PACKRECEIPT-WRITE | `writePackReceipt` added to all three success paths in pack-deploy: single-pass staged, single-pass direct, and split path (`executeSplitPath`). `packSignature` propagated from ClusterPack status through all paths. `TenantDynamicClient` used for all tenant writes. SSA patch via `conductor-pack-deploy` field manager. Verified: `InfrastructurePackReceipt/nginx-ccs-dev` exists in `ont-system` on ccs-dev with correct packSignature. | conductor session/15 6fe4d5c |
| wrapper-runner RBAC lifecycle | `ensureWrapperRunnerResources` added to `ensureTenantOnboarding` in platform (`taloscluster_helpers.go`). Creates SA/Role/RoleBinding/ClusterRoleBinding per tenant at namespace creation time. Manual lab YAML (`wrapper-runner-ccs-dev.yaml`) applied for immediate unblock; operator code now owns this permanently. Deletion path (ClusterRoleBinding cleanup on TalosCluster deletion) tracked as PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE. | platform main 3d39e92 |

---

## Session/15 Drift Detection E2E Closure (2026-05-01)

### New Components

| Component | File | Role |
|-----------|------|------|
| PackReceiptDriftLoop | conductor/internal/agent/pack_receipt_drift_loop.go | role=tenant: verifies PackReceipt signature, checks deployedResources against live cluster, emits/manages DriftSignal on management cluster |
| DriftSignalHandler | conductor/internal/agent/drift_signal_handler.go | role=management: processes pending DriftSignals, deletes PackExecution to retrigger, sets TerminalDrift at escalationThreshold |

### State Machine

Tenant conductor DriftSignal lifecycle (Decision H):
- No signal + drift: CREATE (pending, counter=0)
- Signal pending + drift: UPDATE (counter+1, keep pending)
- Signal queued + drift persists: UPDATE (counter+1, reset to pending -- retrigger failed)
- Signal queued + no drift: SET confirmed (retrigger succeeded)
- Signal confirmed: DELETE on next drift (fresh cycle)
- counter >= escalationThreshold: STOP emitting (terminal)

Management conductor: state=pending + counter < threshold → RETRIGGER (delete PE, set queued). state=pending + counter >= threshold → SET TerminalDrift.

### Live E2E Results (ccs-dev)

| # | Step | Result |
|---|------|--------|
| 1 | Signature verification: packSignature patched signatureVerified=true | PASS |
| 2 | Drift detection: Deployment deleted, DriftSignal emitted (pending, counter=0) | PASS |
| 3 | Management handler: PackExecution deleted, new PE created, state=queued | PASS |
| 4 | pack-deploy Job: nginx-ingress-controller restored (1/1 Running) | PASS |
| 5 | Drift resolved: DriftSignal set to confirmed after nginx restored | PASS (new) |
| 6 | Second deletion: queued+drift → counter=1, pending | PASS (new state machine) |
| 7 | Third deletion: queued+drift → counter=2, pending | PASS |
| 8 | Circuit breaker: counter=3 (=escalationThreshold), TerminalDrift set | PASS |
| 9 | No PackExecution after TerminalDrift | PASS |

### RBAC Fixes Applied

| SA | Cluster | Change |
|----|---------|--------|
| conductor (ont-system) | ccs-dev | `"" *` get/list/watch for drift detection (was limited to 4 resources); `create` added to infrastructure.ontai.dev; `apps *`, `networking.k8s.io *`, `batch *` added |
| conductor-tenant-ccs-dev (seam-tenant-ccs-dev) | ccs-mgmt | Role widened: `infrastructure.ontai.dev *` get/list/watch/create/update/patch; `security.ontai.dev *` get/list/watch |

Both changes also applied to `EnsureRemoteConductorRBAC` in `platform/internal/controller/taloscluster_helpers.go` so future bootstrap deploys get wide RBAC.

### Unit Tests

14 tests passing in `conductor/internal/agent`:
- 3 DriftSignalHandler tests (pending retrigger, escalation threshold, non-pending ignored)
- 11 PackReceiptDriftLoop tests (bootstrap window, valid sig, invalid sig, drift detected, no drift, threshold stops emitting, drift persists queued increments counter, drift resolved confirms signal, pluralizeKind, GVR core group, GVR named group)

---

## Open Work

### Blocking Alpha

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | CLOSED 2026-05-01: full drift detection loop verified. See Session/15 Drift Detection E2E Closure section. |
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | platform | wrapper-runner ClusterRoleBinding must be deleted on TalosCluster deletion (tenant offboarding). ensureWrapperRunnerResources creates it at onboarding; no corresponding cleanup. Track in deletion path. |
| CLUSTERPACK-BL-VERSION-CLEANUP | conductor, seam-core | PackReceipt must carry full resource inventory (GVK + name + namespace per deployed resource). When new PackInstance arrives on tenant cluster, conductor role=tenant diffs old PackReceipt inventory vs new PackInstance manifests and deletes orphaned resources (present in old receipt, absent in new manifests). This ensures clean version upgrades and prevents resource stranding when components are removed. |
| CONDUCTOR-BL-DRIFT-SIGNAL | conductor | CLOSED 2026-05-01: DriftSignal mechanism fully implemented and tested. PackReceiptDriftLoop + DriftSignalHandler. 14 unit tests. Live E2E: 3 retrigger cycles, TerminalDrift at threshold. See Session/15 Drift Detection E2E Closure. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull conductor-tenant RBACProfile from seam-tenant-{cluster} on management cluster and write it into ont-system on the tenant cluster. Guardian side complete (PR #18 pending). Conductor pull loop not yet implemented. |

### Next Session

| ID | Component | Description |
|----|-----------|-------------|
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | Add RBACProfile validation webhook; route seam-operator label profiles through management-maximum validation. |
| CONDUCTOR-BL-SIGNING-KEY-TENANT | conductor | Enable bundle for tenant clusters (role=tenant) should not mount the signing PRIVATE key. Public key only for PackInstance signature verification (INV-026). The compiler currently generates and mounts a full signing keypair for all clusters. For tenant clusters: only the management cluster's public key should be present (for verifying signed PackInstances). This is a compiler + enable bundle change. |

---

## Next Session Candidates

1. **TENANT-CLUSTER-E2E** -- ccs-dev onboarding (awaiting Governor acknowledgement).
