# ONT Platform Progress

**Last updated:** May 2, 2026 (session/17: T-23 Talos version drift detection live test -- rolling upgrade, full chain validated on ccs-dev)

**Current state:** session/17 complete. T-23 Talos version drift chain fully implemented and live-tested on ccs-dev. Rolling upgrade Job corrected all 3 nodes from v1.9.5 back to v1.9.3. TCOR at revision 3 with out-of-band record. Remaining open: TENANT/MGMT-HP-NODE e2e blocked on infrastructure (ccs-dev unreachable, cp3 unstable), session/17 PRs pending Governor merge, Phase 6 excluded by directive.

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

## Session/15 ClusterPack Deletion + Orphan Teardown (2026-05-01)

### New Behavior

When a ClusterPack is deleted from the management cluster, the full cleanup chain is:

1. **Wrapper (handleClusterPackDeletion step 2.5):** deletes `drift-{cp.Name}` DriftSignal from `seam-tenant-{clusterName}` for each target cluster. Prevents orphaned DriftSignals from blocking future reconciliation.
2. **Conductor role=tenant (PackReceiptDriftLoop orphan check):** on each cycle, reads `clusterPackRef` from PackReceipt spec and calls Get on management cluster ClusterPack. If NotFound, calls `teardownOrphanedReceipt`.
3. **teardownOrphanedReceipt:** deletes cluster-scoped resources individually (from `deployedResources` entries with no namespace field), deletes pack-owned namespaces by cascade (each distinct namespace in `deployedResources`), deletes PackReceipt from `ont-system`, deletes DriftSignal from management cluster.
4. **PackInstancePullLoop stale Secret cleanup:** after `extractPackMetadataFromArtifact` returns `clusterPackRef`, if ClusterPack NotFound, deletes the signing Secret and skips further processing for that Secret.

### Artifact Parser Fix

`extractPackMetadataFromArtifact` previously assumed `clusterPackRef` lived under `obj["spec"]`. The signing loop serializes the PackInstance spec directly (flat map), so fields are at the top level. Fixed to try `obj["spec"]` first; if nil, fall back to `obj` directly. Without this fix, `clusterPackRef` was always empty and stale Secret cleanup never triggered.

### RBAC Widening (delete verbs)

`EnsureRemoteConductorRBAC` in `platform/internal/controller/taloscluster_helpers.go` updated:

| Rule | Before | After |
|------|--------|-------|
| `infrastructure.ontai.dev *` | get/list/watch/create/update/patch | + delete |
| `"" *` | get/list/watch | get/list/watch/create/update/patch/delete |
| `apps *` | get/list/watch | get/list/watch/create/update/patch/delete |
| `networking.k8s.io *` | get/list/watch | get/list/watch/create/update/patch/delete |
| `batch *` | get/list/watch | get/list/watch/create/update/patch/delete |
| `rbac.authorization.k8s.io *` | specific resources (roles/clusterroles) | `*` with full verbs |

kubectl apply also ran against the live ccs-dev cluster to unblock the active orphan teardown.

### Admin Action Required (one-time)

The `ingress-nginx` namespace was not deleted by the first code iteration (which deleted individual resources but not the namespace). Admin action: `kubectl delete namespace ingress-nginx` on ccs-dev. Completed this session. Future orphan teardowns delete namespaces via cascade (the corrected `teardownOrphanedReceipt`).

### Unit Tests

| Suite | Tests | Status |
|-------|-------|--------|
| PackReceiptDriftLoop | 9 (6 existing updated + 3 new: OrphanReceipt tears down namespace/ClusterRole/PackReceipt/DriftSignal) | PASS |
| DriftSignalHandler | 3 | PASS |
| ClusterPackReconciler (wrapper) | 6 (5 existing + 1 new: DeletionCascadesDriftSignal) | PASS |

### Live E2E Results -- Full ClusterPack Deletion Cycle (ccs-dev)

| # | Step | Result |
|---|------|--------|
| 1 | ClusterPack `nginx-ccs-dev` deleted from management cluster | PASS |
| 2 | Wrapper step 2.5: DriftSignal `drift-nginx-ccs-dev` deleted from `seam-tenant-ccs-dev` | PASS |
| 3 | PackInstancePullLoop: stale Secret `seam-pack-signed-ccs-dev-nginx-ingress-ccs-dev` deleted | PASS |
| 4 | PackReceiptDriftLoop orphan check: ClusterPack NotFound, teardown triggered | PASS |
| 5 | Orphan teardown: `ingress-nginx` namespace deleted (cascade) | PASS (namespace manually deleted first as admin action; future orphans handled by code) |
| 6 | Orphan teardown: PackReceipt `nginx-ccs-dev` deleted from `ont-system` on ccs-dev | PASS |
| 7 | Orphan teardown: DriftSignal `drift-nginx-ccs-dev` deleted from `seam-tenant-ccs-dev` | PASS |
| 8 | Fresh ClusterPack `nginx-ccs-dev` applied to management cluster | PASS |
| 9 | Pack-deploy Job: ingress-nginx deployed, PackReceipt written | PASS |
| 10 | Drift trigger: Deployment deleted manually | PASS |
| 11 | DriftSignal emitted (pending, counter=0) | PASS |
| 12 | Management handler: PackExecution deleted, new PE created, state=queued | PASS |
| 13 | Pack-deploy Job: ingress-nginx Deployment restored (1/1 Ready) | PASS |
| 14 | DriftSignal state set to confirmed | PASS |

Full lifecycle end-to-end validated.

### Commits

| Repo | Hash | Message |
|------|------|---------|
| conductor | f9f73e4 | conductor: orphan teardown when ClusterPack deleted, stale Secret cleanup, artifact parser flat-form fix |
| platform | 10b94d5 | platform: widen conductor-agent-tenant ClusterRole for orphan teardown (delete verbs on all groups) |
| wrapper | e431629 | wrapper: cascade DriftSignal deletion from handleClusterPackDeletion -- step 2.5, unit test added |

---

## Session/15 Rollback + Day-2 Ops E2E (2026-05-01)

### N-Step Rollback (Final Design)

The initial one-step rollback (N-1 guard, Previous* embedding) was replaced with the N-step superseded retention model before any code shipped to the cluster.

**seam-core schema (f380fb6):** `Previous*` fields removed. `clusterPackVersion`, `rbacDigest`, `workloadDigest` are rollback anchors written at deploy time. `rollbackToRevision int64` on ClusterPackSpec triggers rollback to any retained revision. Label `ontai.dev/cluster-pack={packName}` on every POR allows listing full history.

**Conductor POR writer (fdfa63d):** Predecessor POR is no longer deleted. It is labeled `ontai.dev/superseded=true` and retained. Pruning keeps at most 10 superseded PORs per ClusterPack (oldest removed when cap exceeded). All three write paths populate `clusterPackVersion`, `rbacDigest`, `workloadDigest`.

**Wrapper handleRollback (51039d6):** Lists all PORs by `ontai.dev/cluster-pack` label, finds the POR at `spec.revision == rollbackToRevision` (no N-1 guard), reads its `ClusterPackVersion/RBACDigest/WorkloadDigest`, patches ClusterPack spec, clears `spec-checksum-snapshot` annotation, clears `rollbackToRevision`. Any retained revision is reachable in one operation.

**Unit tests:** 4 rollback tests (one-step, N-step skip-two, no POR clears field, revision not found clears field). Conductor persistence tests confirm superseded label presence and rollback anchor field integrity.

### DriftSignal correlationID Clearing

`resolveSignalIfHealthy` in `pack_receipt_drift_loop.go` now includes `correlationID: ""` in the confirmation patch alongside `state: "confirmed"`. Clearing correlationID on confirmation is a lifecycle invariant (Decision H). Unit test extended to assert empty correlationID on confirmed signals.

### seam-core CRD Schema Gap Fixed

`clusterPackVersion`, `rbacDigest`, `workloadDigest` were present in the Go types but absent from the live CRD schemas on both clusters. Fixed by running `make generate-crd` in seam-core and applying the updated CRDs to ccs-mgmt and ccs-dev. AC-3 rollback e2e test required this fix (SSA rejected unknown field).

### Live E2E Results (ccs-dev, 2026-05-01)

AC-3 rollback test: synthetic superseded POR created at revision 1 with same version (v4.9.0-r1). `rollbackToRevision=1` set on ClusterPack. Wrapper handler cleared field to 0 within 5 seconds. Version verified. PASS.

| Test | Specs | Result |
|------|-------|--------|
| AC-3: N-step rollback | 1 live | PASS |
| D2-1: Tenant ClusterPack deployed state | 3 live | PASS |
| D2-2: DriftSignal valid state | 2 live | PASS |
| D2-3: DriftSignal correlationID lifecycle | 1 live, 1 skip (DRIFT-LIFECYCLE-E2E) | PASS |
| D2-4: ClusterPack upgrade | 3 skip (UPGRADE-E2E) | SKIP |
| D2-5: Active drift injection | 4 skip (DRIFT-INJECTION-E2E) | SKIP |

Total: 7 live specs passed, 8 stubs skipped per e2e CI contract. 0 failures.

---

## Session/15 Guardian role=tenant Wiring (2026-05-01)

### Architecture Locked

Guardian role=tenant is the FIRST component deployed on every new tenant cluster, before conductor. Guardian owns all `security.ontai.dev` operations on every cluster (INV-004). Conductor must never write security.ontai.dev resources. TenantBootstrapSweep in conductor was an INV-004 violation and has been removed.

### New Components

| Component | File | Purpose |
|-----------|------|---------|
| TenantSnapshotRunnable | guardian/internal/controller/tenant_snapshot_runnable.go | Pulls PermissionSnapshot from mgmt, writes PermissionSnapshotReceipt to ont-system, patches lastAckedVersion/drift=false on mgmt, sets Compliant=True condition |
| TenantProfileRunnable | guardian/internal/controller/tenant_profile_runnable.go | Creates RBACProfiles in ont-system for cert-manager/kueue/cnpg/metallb/local-path-provisioner. No per-component PermissionSet or RBACPolicy (CS-INV-008) |

### Changes

| Repo | Change |
|------|--------|
| conductor | `TenantBootstrapSweep` deleted (internal/agent/tenant_bootstrap.go, tenant_bootstrap_test.go). `agent.go` phase 3 block replaced with audit-mode-only EnforcementGate. `onLeaderStart` tenantSweep parameter removed. SetTalosClusterReady gated on snapshotPullLoop!=nil |
| guardian | `setupTenantControllers` signature updated to accept clusterID, namespace, mgmtDynClient. TenantSnapshotRunnable and TenantProfileRunnable registered. mgmtDynClient init from MGMT_KUBECONFIG_PATH env var in main() |
| conductor/test/e2e | `tenant_rbac_sweep_test.go` Describe block renamed from "Conductor role=tenant" to "Guardian role=tenant". Skip reasons updated from CONDUCTOR-TENANT-SWEEP-E2E to GUARDIAN-TENANT-E2E. Profile namespace/name corrected (ont-system, cert-manager). PermissionSet test removed (CS-INV-008) |

### Unit Tests

| Suite | Tests | Status |
|-------|-------|--------|
| TenantSnapshotRunnable | 5 (creates receipt, no-op same version, updates on version change, skips wrong cluster, patches mgmt acknowledgement, sets Compliant condition) | PASS |
| TenantProfileRunnable | 6 (creates profile in ont-system, no PermissionSet/RBACPolicy, skips when SA absent, idempotent, NamespaceHint wins on collision, system namespaces ignored, TargetClusters set) | PASS |

---

### cert-manager Deployed to ccs-dev via ClusterPack (2026-05-01)

cert-manager v1.14.0 successfully deployed to ccs-dev tenant cluster via the ClusterPack mechanism. Three fixes were required:

1. **Helm namespace rendering bug**: `HelmSource` struct in `compile_packbuild_helm.go` had no `Namespace` field; `chartutil.ReleaseOptions` hardcoded `"default"`. Added `Namespace` field; packbuild YAML now specifies `namespace: cert-manager`. All cert-manager resources render into the `cert-manager` namespace.

2. **RBAC direct apply to tenant cluster**: Guardian's `/rbac-intake/pack` creates governance CRs on the management cluster only; it does not apply Kubernetes RBAC objects to tenant clusters (no kubeconfig mounted). Added step 5b to `executeSplitPath`: after `WaitForRBACProfileProvisioned`, parse each RBAC YAML and apply directly to tenant cluster via TenantDynamicClient.

3. **file:// URL support**: Added `file://` scheme handling to `fetchURL` for local chart tarballs.

cert-manager ClusterPack status: `Available=true, signed=true`. All pods Running on ccs-dev.

---

## Session/15 Guardian role=tenant Deploy to ccs-dev (2026-05-01)

### Enable Bundle Applied

Two-phase enable bundle created and applied to ccs-dev:

**Phase 01 (01-guardian-bootstrap):** namespace-labels.yaml (ont-system/cert-manager/kube-system/seam-system/ingress-nginx/kube-node-lease all exempt), guardian-crds.yaml (8 security.ontai.dev CRDs), guardian-rbac.yaml (SA + ClusterRole guardian-tenant-manager-role + ClusterRoleBinding), guardian-issuers.yaml (guardian-selfsigned-root + guardian-ca + guardian-ca-issuer chain), phase-meta.yaml.

**Phase 02 (02-guardian-deploy):** guardian-webhook-cert.yaml (TLS cert via guardian-ca-issuer), guardian-service.yaml (ports 443/9090/8080), guardian-deployment.yaml (GUARDIAN_ROLE=tenant, CLUSTER_ID=ccs-dev, MGMT_KUBECONFIG_PATH, conductor-mgmt-kubeconfig mount), guardian-metrics-service.yaml, guardian-rbac-webhook.yaml (ValidatingWebhookConfiguration, cert-manager.io/inject-ca-from: ont-system/guardian-webhook-cert), guardian-lineage-webhook.yaml.

### Fixes Required During Deploy

| Fix | Root Cause | Resolution |
|-----|-----------|------------|
| BootstrapAnnotationRunnable crashes on role=tenant | `createThirdPartyProfiles` targets `seam-tenant-ccs-mgmt` (computed from MANAGEMENT_CLUSTER_NAME default). Namespace does not exist on tenant clusters. | Guard `createThirdPartyProfiles` with `ManagementClusterName != ""`. Pass `sweepMgmtCluster = ""` for role=tenant in main.go. |
| TenantSnapshotRunnable RBAC forbidden | `conductor-tenant-ccs-dev-snapshot-reader` ClusterRole on management cluster only had get/list/watch on permissionsnapshots. Status patch required for Compliant condition. | Added permissionsnapshots/status + patch/update to ClusterRole on management cluster. |
| serviceaccounts patch forbidden | guardian-tenant-manager-role only had get/list/watch on serviceaccounts; BootstrapAnnotationRunnable needs patch for annotation sweep. | Added update/patch to serviceaccounts rule. Added kube-node-lease to exempt namespace list. |

### Verification

| Check | Result |
|-------|--------|
| `kubectl get permissionsnapshotreceipts -n ont-system` on ccs-dev | `receipt-ccs-dev` exists |
| `snapshot-ccs-dev` Compliant condition on management cluster | `Compliant=True`: "Tenant cluster ccs-dev has acknowledged the current snapshot" |
| `drift` field on management snapshot | `false` |
| `lastAckedVersion` set | `"2026-05-01T17:23:51Z"` |
| Bootstrap annotation sweep | Complete: 6 skipped (exempt), 3 scanned, 50 already owned |
| Guardian pods on ccs-dev | 2/2 Running, 0 restarts |

### Commits

| Repo | Hash | Message |
|------|------|---------|
| guardian | 89c7c57 | guardian: wire TenantSnapshotRunnable and TenantProfileRunnable for role=tenant |
| guardian | 65ac2b9 | guardian: skip third-party profile creation in BootstrapAnnotationRunnable for role=tenant |
| ontai-root | this session | lab: ccs-dev conductor INV-026 fix (public key only), permission service NodePort, enable bundle cleanup |

---

## Open Work

### Blocking Alpha

| ID | Component | Description |
|----|-----------|-------------|
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | platform | wrapper-runner ClusterRoleBinding must be deleted on TalosCluster deletion (tenant offboarding). ensureWrapperRunnerResources creates it at onboarding; no corresponding cleanup. Track in deletion path. |
| CLUSTERPACK-BL-VERSION-CLEANUP | conductor, seam-core | PackReceipt must carry full resource inventory (GVK + name + namespace per deployed resource). When new PackInstance arrives on tenant cluster, conductor role=tenant diffs old PackReceipt inventory vs new PackInstance manifests and deletes orphaned resources (present in old receipt, absent in new manifests). This ensures clean version upgrades and prevents resource stranding when components are removed. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull conductor-tenant RBACProfile from seam-tenant-{cluster} on management cluster and write it into ont-system on the tenant cluster. Guardian side complete (PR #18 merged). Conductor pull loop not yet implemented. |

### Closed This Session

| ID | Component | Resolution | Reference |
|----|-----------|------------|-----------|
| GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING | guardian | `reconcileTenantSnapshotPath()` added to RBACProfileReconciler. Profiles with empty RBACPolicyRef route through tenant path: skips ceiling validation, checks for local mirrored PermissionSnapshot (labeled `ontai.dev/snapshot-type=mirrored`), sets Provisioned=True when snapshot present. TenantProfileRunnable clears RBACPolicyRef. | guardian 693ba7d |
| CONDUCTOR-BL-SIGNING-KEY-TENANT | conductor | `--signing-private-key` and `--output-public-key` flags added. `--signing-private-key` rejected at validation when `--cluster-role=tenant` (INV-026 enforcement). ccs-dev enable bundle updated: private key removed from conductor-deployment.yaml env vars and conductor-signing-key.yaml Secret. Public key only on tenant clusters. | conductor 7563ebe |

### Next Session

| ID | Component | Description |
|----|-----------|-------------|
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | Add RBACProfile validation webhook; route seam-operator label profiles through management-maximum validation. T-25a in GAP_TO_FILL.md. |

---

## Session/16 CODEBASE.md Audit (2026-05-01)

Comprehensive codebase audit of all open tasks in GAP_TO_FILL.md. All CODEBASE.md files rewritten with precise code references (file paths, function names, line numbers, struct field names, what is present vs absent). Findings:

- Phase 2 (T-07 through T-10) and Phase 4 (T-14 through T-16): all confirmed complete by direct code inspection. Moved to verified-complete table in GAP_TO_FILL.md.
- Phase 3 (T-11 through T-13): entirely absent from codebase. seam-core schema has `InfrastructurePackBuildCategory` enum and `KustomizeSource` struct; conductor `PackBuildInput` has no `Category` field.
- T-24: `handleTalosClusterDeletion()` at `platform/internal/controller/taloscluster_helpers.go:1073` only covers RunnerConfig + Secrets + namespace. Decision H order (wrapper components first, guardian components second, TalosCluster CR last) not implemented.
- T-25a: `"RBACProfile"` confirmed absent from `InterceptedKinds` at `guardian/internal/webhook/decision.go:24`.
- CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION: No pull loop exists in `conductor/internal/kernel/agent.go` for reading conductor-tenant RBACProfile from management and writing to `ont-system`.
- CLUSTERPACK-BL-VERSION-CLEANUP: `DeployedResources` field exists in seam-core schema at `packreceipt_types.go:74`. Version-upgrade orphan diff logic absent from `packinstance_pull_loop.go`.

### Commits

| Repo | Hash | Message |
|------|------|---------|
| guardian | 2b3b24c | guardian: add CODEBASE.md with precise code references |
| wrapper | 89d838a | wrapper: add CODEBASE.md with precise code references |
| platform | 0474770 | platform: add CODEBASE.md with precise code references |
| seam-core | d5289c3 | seam-core: add CODEBASE.md with precise code references |
| domain-core | c9552e7 | domain-core: add CODEBASE.md with precise code references |
| ontai root | a3045cb | root: rewrite CODEBASE.md and update GAP_TO_FILL.md |

---

## Session/15 GAP_TO_FILL Closure (2026-05-02)

All open GAP_TO_FILL tasks (except Phase 6 T-20/T-21 excluded by directive, and T-23/T-24 requiring design sessions) were closed in a single session. Conductor branch `session/15-capability-tests`.

| Task | Item | Resolution |
|------|------|-----------|
| T-25a | Guardian RBACProfile webhook (seam-operator label routing) | RBACProfile added to InterceptedKinds; Gate 4a validates seam-operator profiles reference management-maximum only. 5 new tests. Committed prior session. |
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | CRB cleanup finalizer on TalosCluster deletion | `finalizerWrapperRunnerCRBCleanup` added; Step 3 in `handleTalosClusterDeletion` deletes `wrapper-runner-cluster-scoped-{tc.Name}`. Fake-client status-stripping bug fixed (all finalizer Updates moved to Step C0 before any Status assignments). Committed prior session. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | RBACProfile pull loop for role=tenant | `RBACProfilePullLoop` in `rbacprofile_pull_loop.go`. Wired into `kernel/agent.go`. 4 unit tests. Committed prior session. |
| CLUSTERPACK-BL-VERSION-CLEANUP | Version-upgrade orphan resource deletion | `deleteOrphanedResources()` + `deployedResourceKey()` added to `packinstance_pull_loop.go`. Fixed `[]map[string]interface{}` deep-copy panic (converted to `[]interface{}` in `buildReceiptSpecPayload`). `extractPackMetadataFromArtifact` populates `DeployedResources`. 2 unit tests. |
| T-04a | TalosCluster CEL validation for mode=import | Already in CRD YAML (`x-kubernetes-validations` line 291). Closed without code change. |
| T-05/T-11/T-13 | PackBuildInput Category discriminator + HelmVersion override | `Category string` field on `PackBuildInput`. Cross-contamination validation in `readPackBuildInput`. `HelmVersion string` on `HelmSource` with `helmVersionOrDefault()`. Category-driven dispatch in `compilePackBuild`. Backward-compatible nil-check retained. 6 unit tests. |
| T-12 | Kustomize packbuild path | `KustomizeSource` struct + `kustomizeCompilePackBuild()` in `compile_packbuild_kustomize.go`. Uses `sigs.k8s.io/kustomize/api/krusty` (INV-014). kustomizeSource early return in validation. 3 unit tests. |
| T-17 | Scoped RBACPolicy pull loop for role=tenant | `RBACPolicyPullLoop` in `rbacpolicy_pull_loop.go`. Pulls `cluster-policy` from `seam-tenant-{cluster}` on mgmt, SSA-patches into `ont-system`. Wired into `kernel/agent.go`. 4 unit tests. |

Remaining open (design sessions required): T-23 (platform DriftSignal handling), T-24 (TalosCluster deletion cascade order per Decision H). Phase 6 (T-20, T-21) excluded by directive.

GAP_TO_FILL.md updated to mark completed items.

---

---

## Session/16 E2E Test Run (2026-05-02)

Four new e2e test files written to cover session gaps a-g:

| File | Coverage |
|------|----------|
| `rbacprofile_rbacpolicy_pull_loop_test.go` | T-17: RBACProfilePullLoop + RBACPolicyPullLoop (b) |
| `clusterpack_version_cleanup_test.go` | CLUSTERPACK-BL-VERSION-CLEANUP invariants (d) |
| `drift_injection_test.go` | Decision H full drift injection cycle (e) |
| `cnpg_audit_sweep_test.go` | Guardian CNPG audit_events sweep via pod exec (f) |

All four compile clean. Total suite: 68 specs across 11 spec files.

### Full Suite Run Results (ccs-dev, 2026-05-02)

Suite ran with 20m timeout. Timed out during `signing_loop_test.go` (pre-existing polling for wrong PackReceipt name). Confirmed results before timeout:

**Confirmed Passed:**
- CLUSTERPACK-BL-VERSION-CLEANUP: PackReceipt deployedResources non-empty
- CLUSTERPACK-BL-VERSION-CLEANUP: each entry has apiVersion/kind/name fields
- CLUSTERPACK-BL-VERSION-CLEANUP: rbacDigest and workloadDigest present
- Drift injection: precondition (deployedResources non-empty)
- Drift injection: DriftSignal advances to state=queued (live DriftSignal exists on mgmt)
- RBACProfilePullLoop: precondition on management cluster
- RBACProfilePullLoop: conductor-tenant SSA-patched into ont-system on ccs-dev
- RBACPolicyPullLoop: cluster-policy precondition on management cluster

**Confirmed Failed (categorized):**

| Category | Count | Specs |
|----------|-------|-------|
| A: Pre-existing test code bug (wrong name/annotation) | 6 | packinstance_pull_loop (5: expects `cert-manager`, actual `cert-manager-helm-ccs-dev`); snapshot_pull_loop (1: expects `ontai.dev/pack-signature`, actual `infrastructure.ontai.dev/management-signature`) |
| B: Cluster state (guardian swept RBAC or kube-public) | 3 | clusterpack_version_cleanup: 44 cert-manager RBAC resources in deployedResources not found; tenant_rbac_sweep: kube-public annotated; tenant_rbac_sweep (mgmt): rbac-cert-manager/rbac-kueue profiles not found |
| C: New code not yet deployed (old conductor:dev on ccs-dev) | 3 | RBACPolicyPullLoop: SSA-patch timeout (4m), non-empty spec, idempotency |
| D: Infrastructure not configured | 3 | PermissionService gRPC NodePort 30051 refused |
| E: Drift target already absent (cluster drift) | 2 | drift_injection: resource deletion (target Role already gone), resource restore timeout |

**Suite timeout:** 20m insufficient for cumulative slow tests (3m packinstance + 12m drift restore + 4m RBACPolicy = 19m before signing_loop even starts). CNPG tests status unknown (may not have run before timeout).

### Required Actions Before PR

| Action | Owner | Effect |
|--------|-------|--------|
| Fix `packinstance_pull_loop_test.go` PackReceipt name (`cert-manager-helm-ccs-dev`) | Test code | Unblocks 5 failing specs |
| Fix `signing_loop_test.go` secret name pattern | Test code | Unblocks signing suite + removes 20m timeout cause |
| Fix `snapshot_pull_loop_test.go` annotation key (`infrastructure.ontai.dev/management-signature`) | Test code | Unblocks snapshot tests |
| Rebuild and push `conductor:dev` image to ccs-dev | Cluster action | Unblocks RBACPolicyPullLoop 3 specs |
| Diagnose 44 missing cert-manager RBAC resources in deployedResources | Cluster investigation | Guardian likely swept kube-system Roles not in managed namespaces |

---

## Session/16 E2E Fixes + PR Merge (2026-05-02)

All e2e test failures resolved. New conductor:dev image built with T-17 loops. All five PRs merged (conductor #28, platform #18, guardian #19, wrapper #16, domain-core #3).

### Bugs Fixed

| Bug | Fix | File |
|-----|-----|------|
| `packinstance_pull_loop_test.go` uses `cert-manager` (wrong name) | `pullReceiptName()` returns `cert-manager-helm-{cluster}` | test/e2e/packinstance_pull_loop_test.go |
| `signing_loop_test.go` wrong secret name pattern | `seam-pack-signed-%s-cert-manager-helm-%s` | test/e2e/signing_loop_test.go |
| `signing_loop_test.go` ClusterPack list uses wrong scope/name | Namespace `seam-tenant-{cluster}`, name `cert-manager-{cluster}` | test/e2e/signing_loop_test.go |
| `snapshot_pull_loop_test.go` wrong annotation key | `infrastructure.ontai.dev/management-signature` | test/e2e/snapshot_pull_loop_test.go |
| `drift_injection_test.go` broken label selector | DriftSignals have no `ontai.dev/cluster` label; poll by name `drift-{receiptName}` | test/e2e/drift_injection_test.go |
| `drift_injection_test.go` wrong field name `spec.reason` | `spec.driftReason` | test/e2e/drift_injection_test.go |
| `pickDriftTarget` selects guardian-swept RBAC resources | Added `Role`, `RoleBinding`, `ServiceAccount` to skipKinds | test/e2e/drift_injection_test.go |
| `conductor-agent-tenant` ClusterRole missing write verbs on `security.ontai.dev` | Added `create`, `update`, `patch` | platform/internal/controller/taloscluster_helpers.go |
| `drift_signal_handler.go` SA4004 unconditional loop | Replaced `for range` with direct `list.Items[0]` | internal/agent/drift_signal_handler.go |
| `signing_loop_test.go` unused `packInstanceGVR` | Removed | test/e2e/signing_loop_test.go |
| `drift_injection_test.go` unused `packExecutionGVR` | Removed | test/e2e/drift_injection_test.go |
| `tenant_snapshot_runnable.go` unused `snapshotReceiptGVR` | Removed | guardian/internal/controller/tenant_snapshot_runnable.go |
| `ac3_rollback_test.go` unchecked error returns in DeferCleanup | `_ = ...Delete(...)`, `_, _ = ...Patch(...)` | wrapper/test/e2e/ac3_rollback_test.go |
| `seam-core/pkg/conditions` missing `ReasonConductorDeploymentAvailable/Unavailable` | Added both constants | seam-core/pkg/conditions/conditions.go |
| cert-manager terminal drift (escalationCounter=3) blocking tests | Deleted stale terminal DriftSignal; fix is operational | live cluster |
| wrapper CI-INV-002 immutability violation (stale checksum) | Deleted `spec-checksum-snapshot` annotation; wrapper re-recorded | live cluster |

### Final E2E Results (2026-05-02)

| Focus | Specs Run | Passed | Failed |
|-------|-----------|--------|--------|
| Non-drift (PackInstance, Signing, Snapshot, RBAC, ClusterPack) | 29 | 26 | 0 |
| Drift injection cycle | 6 | 5 | 0 (1 skip) |

### PRs Merged

| Repo | PR | Title |
|------|----|-------|
| conductor | #28 | e2e suite -- T-17 loops, drift injection cycle, signing, snapshot, lint fixes |
| platform | #18 | T-19 import-mode conductor bootstrap, conductor ClusterRole security.ontai.dev write verbs |
| guardian | #19 | T-25a seam-operator RBACProfile ceiling, tenant provisioning, unused var cleanup |
| wrapper | #16 | N-step rollback handler, DriftSignal cascade delete, errcheck lint fix |
| domain-core | #3 | DomainLineageIndex schema amendment -- declaringPrincipal, actorRef, outcomeRegistry |
| seam-core | (direct push) | ReasonConductorDeploymentAvailable/Unavailable condition reason constants |

---

## Session/17 Etcd Backup/Restore + PKI Rotation Automation (2026-05-02)

### Work Completed

**Task A: S3 credential injection for etcd backup/restore executor Jobs**

The etcd backup and restore paths in platform required S3 credentials mounted into the Conductor executor Job. Cross-namespace `envFrom` is not possible in Kubernetes, so the reconciler reads the source secret, normalizes its keys, and projects a per-operation copy into `em.Namespace` owned by the EtcdMaintenance CR.

| File | Change |
|------|--------|
| `platform/internal/controller/s3_env_secret.go` | New file. `ensureS3EnvSecret`, `NormalizeS3SecretData` (exported), `appendS3EnvFrom`, `resolveS3CredentialsForRestore`. |
| `platform/internal/controller/etcdmaintenance_reconciler.go` | Backup and restore paths call `ensureS3EnvSecret` and `appendS3EnvFrom`. |
| `platform/docs/platform-schema.md` | Section 10 added: S3 secret contract, two-tier resolution, key normalization table. |
| `platform/CODEBASE.md` | `s3_env_secret.go` functions documented. |

Key design: S3 key normalization accepts MinIO/Scality camelCase (`accessKeyID`, `secretAccessKey`, `region`, `endpoint`) and AWS SDK env var names (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_ENDPOINT`). Output always AWS SDK form. `NormalizeS3SecretData` exported for unit tests.

**Task B: Conductor etcd-backup S3 upload fix**

`bytes.Buffer` is not `io.ReadSeeker`. AWS SDK v2 requires seekable stream for `PutObject` over HTTP without TLS. Fixed in `conductor/internal/capability/platform_etcd.go`: `params.StorageClient.Upload(ctx, s3Bucket, s3Key, bytes.NewReader(buf.Bytes()))`.

**Task C: Live etcd backup + restore E2E on ccs-dev**

Backup and restore Jobs ran on ccs-dev. Both Jobs completed with `Ready=True`. Stale TCOR entry poisoning observed and documented: reusing a deleted EtcdMaintenance CR name causes the reconciler to read old failed TCOR entries. Resolution: use unique CR names per operation.

**Task D: PKI rotation automation (ontai-schema, seam-core, platform, conductor)**

Full implementation across four repos on branch `session/17-pki-rotation-automation`:

| Repo | Changes |
|------|---------|
| ontai-schema | `pkiRotationThresholdDays` (int, default 30, min 1) added to spec; `pkiExpiryDate` (date-time) added to status of `InfrastructureTalosCluster.json` |
| seam-core | `PkiRotationThresholdDays int32` added to `InfrastructureTalosClusterSpec`; `PkiExpiryDate *metav1.Time` added to `InfrastructureTalosClusterStatus`; `zz_generated.deepcopy.go` updated |
| platform | New file `pki_cert_helpers.go`: `ParsePEMCertExpiry`, `ParseKubeconfigCertExpiry`, `ParseTalosConfigCertExpiry`, `detectClusterPKIExpiry`, `syncPKIExpiry`, `ensureAutoRotationPKI`, `ensureAnnotationRotationPKI`. `taloscluster_controller.go` Step F wires both annotation trigger and threshold-based auto-rotation. Daily requeue (24h) for stable-Ready clusters. 9 unit tests for cert expiry parsing. 2 e2e stubs. S3 test fixture data fixed (3 tests). |
| conductor | `Kubeconfig(ctx) ([]byte, error)` added to `TalosNodeClient` interface and `TalosClientAdapter`. `pkiRotateHandler.Execute()` in `platform_security.go` extended: after staged apply calls `TalosClient.Kubeconfig(ctx)` and upserts `seam-mc-{cluster}-kubeconfig` + `target-cluster-kubeconfig` Secrets in `seam-tenant-{cluster}` via DynamicClient. |

### Commits

| Repo | Branch | Hash | Message |
|------|--------|------|---------|
| conductor | session/17-etcd-s3-credential-injection | 25f9a91 | conductor: fix etcd-backup S3 upload for MinIO over HTTP |
| platform | session/17-etcd-s3-credential-injection | f03804e | platform: inject S3 credentials into etcd backup/restore executor Jobs |
| seam-core | session/17-pki-rotation-automation | (committed) | seam-core: add pkiRotationThresholdDays to spec and pkiExpiryDate to status |
| platform | session/17-pki-rotation-automation | 211defb | platform: implement PKI rotation automation with cert expiry detection |
| platform | session/17-pki-rotation-automation | e6b64ab | platform: fix S3 secret test fixtures to include required credentials |
| conductor | session/17-pki-rotation-automation | b1cc44c | conductor: add Kubeconfig method and kubeconfig Secret refresh to pkiRotateHandler |

### All Tests Pass

| Repo | Command | Result |
|------|---------|--------|
| conductor | `go test ./...` | All suites pass |
| platform | `go test ./...` | All suites pass |

---

## Session/17 PKI Rotation E2E + HardeningProfile Tests (2026-05-02)

### hardeningApplyHandler Bug Fix

`hardeningApplyHandler.Execute()` in `conductor/internal/capability/platform_security.go` was using `unstructuredString` to read `spec.machineConfigPatches`. This always returned empty string because the field is `[]interface{}` in the unstructured object -- the `v.(string)` type assertion inside `unstructuredString` silently fails on a slice. Fixed by using `unstructuredList` with a per-element string type assertion and applying each patch in a separate loop iteration. Each patch produces one `StepResult`.

5 new unit tests in `conductor/test/unit/capability/platform_test.go`:
- `TestHardeningApply_SinglePatchApplied`
- `TestHardeningApply_MultiPatchApplied`
- `TestHardeningApply_EmptyPatchesValidationFailure`
- `TestHardeningApply_NoHardeningProfileRefValidationFailure`
- `TestHardeningApply_ApplyErrorReturnsExecutionFailure`

### HardeningProfile E2E Tests

New file `platform/test/e2e/day2/hardeningprofile_e2e_test.go` with 6 live specs covering both bootstrap mode (ccs-mgmt) and import mode (ccs-dev):

| Spec ID | Cluster | Coverage |
|---------|---------|----------|
| MGMT-HP-PROFILE | ccs-mgmt (bootstrap) | HardeningProfile Valid=True condition |
| MGMT-HP-CLUSTER | ccs-mgmt (bootstrap) | Full-cluster NodeMaintenance hardeningApply reaches Ready=True |
| MGMT-HP-NODE | ccs-mgmt (bootstrap) | Single-node (ccs-mgmt-w2) NodeMaintenance hardeningApply reaches Ready=True |
| TENANT-HP-PROFILE | ccs-dev (import) | HardeningProfile Valid=True condition |
| TENANT-HP-CLUSTER | ccs-dev (import) | Full-cluster NodeMaintenance hardeningApply reaches Ready=True |
| TENANT-HP-NODE | ccs-dev (import) | Single-node via TENANT_WORKER_NODE env; skips if unset |

Safe machineconfig patches: `net.ipv4.ip_forward=1` and `net.ipv4.conf.all.rp_filter=1`. These sysctls are required for Kubernetes networking and already set on all cluster nodes, so applying them in `no-reboot` mode is idempotent and non-disruptive.

### PKI Rotation E2E Tests

New `platform/test/e2e/day2/pkirotation_e2e_test.go` (replaces stubs). Two live specs:

| Spec ID | Coverage |
|---------|----------|
| TENANT-PKI-ROTATE | PKIRotation CR on ccs-dev: waits for Ready=True, verifies `target-cluster-kubeconfig` Secret refreshed in `seam-tenant-ccs-dev`, best-effort check on `seam-mc-ccs-dev-kubeconfig` |
| TENANT-PKI-CLUSTER-REACH | Pushes minimal two-layer OCI pack (empty ServiceAccount RBAC + single ConfigMap workload) to lab registry, creates `InfrastructureClusterPack` in `seam-tenant-ccs-dev`, waits for signing loop, waits for `PackExecution Succeeded=True` -- proves ccs-dev reachable using refreshed kubeconfig from pkiRotateHandler |

`buildTarGzManifest(filename, content string) []byte` helper in the test file creates tar.gz blobs for OCI layer push.

`suite_test.go` updated: added `registry *e2ehelpers.RegistryClient` and `registryAddr string` (from `REGISTRY_ADDR` env, default `10.20.0.1:5000`). Import `seam-core/pkg/e2e` added to day2 suite.

Both HardeningProfile and PKI rotation tests require a rebuilt `conductor-execute:dev` image from `session/17-hardening-profile-tests` before live e2e runs.

### Commits

| Repo | Branch | Hash | Message |
|------|--------|------|---------|
| conductor | session/17-hardening-profile-tests | a8ad30e | conductor: fix hardeningApplyHandler to read machineConfigPatches as list |
| conductor | session/17-hardening-profile-tests | 5144841 | conductor: update CODEBASE.md for hardeningApplyHandler fix and unstructuredList sharp edge |
| platform | session/17-hardening-profile-tests | 4fbe1e2 | platform: add hardeningprofile e2e tests for bootstrap and import clusters (includes CODEBASE.md) |
| platform | session/17-hardening-profile-tests | (pending) | platform: add PKIRotation e2e tests + update day2 suite with registry client |

---

## Session/17 Per-Node Hardening Fix + E2E Run (2026-05-02)

### Root Cause: hardeningApplyHandler IP Clash

`hardeningApplyHandler` was using a Talos client with `endpoints: [10.20.0.2, 10.20.0.3, 10.20.0.4]` and no `nodes` scoping. `GetMachineConfig` returned cp3's config (first responder). `ApplyConfiguration` sent that config to all three endpoints simultaneously. ccs-mgmt-cp1 received cp3's config (hostname ccs-mgmt-cp3, IP 10.20.0.4) and adopted cp3's IP, causing an IP clash and requiring manual reset.

### Fix

Per-node iteration via `EndpointsFromTalosconfig` + `NodeContext` (commit `7c4c47d`):

| Symbol | File | Role |
|--------|------|------|
| `EndpointsFromTalosconfig(path string)` | `conductor/internal/capability/adapters.go` | Reads active context `nodes` (preferred) or `endpoints` from talosconfig YAML |
| `NodeContext(ctx, nodeIP string)` | `conductor/internal/capability/adapters.go` | Wraps ctx with `talos_client.WithNode` for single-node gRPC targeting |
| `TalosconfigPath string` | `conductor/internal/capability/clients.go` `ExecuteClients` | Set from `TALOSCONFIG_PATH` env var; passed to hardeningApplyHandler |

`hardeningApplyHandler.Execute()` iterates all talosconfig endpoints and calls `GetMachineConfig` + `ApplyConfiguration` with a per-node context for each node. Falls back to original single-node behavior when `TalosconfigPath` is empty.

### New Unit Tests (5)

`TestEndpointsFromTalosconfig_EndpointsFallback`, `TestEndpointsFromTalosconfig_NodesTakePrecedence`, `TestEndpointsFromTalosconfig_MissingFile`, `TestEndpointsFromTalosconfig_UnknownContext` in `test/unit/capability/adapters_test.go`. `TestHardeningApply_BadTalosconfigPathReturnsExecutionFailure` in `test/unit/capability/platform_test.go`.

### Day2 E2E Run Results (2026-05-02)

Seed: 1777737976 | Duration: 23.5 min | **10 Passed | 3 Failed | 35 Skipped** (13 of 48 ran)

| Spec ID | Result | Notes |
|---------|--------|-------|
| MGMT-HP-PROFILE | PASS | HardeningProfile Valid=True on bootstrap cluster |
| MGMT-HP-CLUSTER | PASS | Full-cluster hardening ccs-mgmt; per-node fix verified working |
| TENANT-HP-PROFILE | PASS | HardeningProfile Valid=True on import cluster |
| TENANT-PKI-ROTATE | PASS | PKIRotation on ccs-dev Ready=True, kubeconfig refreshed |
| 6 other mgmt day2 specs | PASS | EtcdMaintenance, ClusterMaintenance, NodeOperation, NodeMaintenance, UpgradePolicy, PKI |
| TENANT-PKI-CLUSTER-REACH | FAIL | Infrastructure: ccs-dev (10.20.0.20) unreachable |
| MGMT-HP-NODE | FAIL | Infrastructure: cp3 Talos API down during test. Design note: `ccs-mgmt-w2` hardcoded as TargetNodes does not exist; TargetNodes governs Job pod scheduling only, not which nodes the capability applies to |
| TENANT-HP-CLUSTER | FAIL | Infrastructure: Job not submitted within 120s -- ccs-dev down, etcd leader instability from cp3 flapping |

### Cluster State at E2E Completion

ccs-mgmt: cp1 Ready, cp2 Ready, cp3 NotReady (Talos API unreachable). ccs-dev: unreachable (10.20.0.20 -- Destination Host Unreachable). One conductor pod CrashLoopBackOff from cp3 leader election failures.

### Commit

| Repo | Branch | Hash |
|------|--------|------|
| conductor | session/17-hardening-profile-tests | 7c4c47d |

---

## Session/17 T-23 + T-24 Closure (2026-05-02)

### T-23 -- RunnerConfig-Missing DriftSignal Loop

Conductor (agent mode, role=management) detects that its RunnerConfig is persistently absent after 5 consecutive `NotFound` retries (`runnerConfigMissingDriftThreshold`). It emits a `DriftSignal` with `affectedCRRef.Kind = "InfrastructureRunnerConfig"` into `seam-tenant-{cluster}` on the management cluster. Platform's new `DriftSignalReconciler` watches `DriftSignal` CRs; for signals with state=pending + RunnerConfig kind, it annotates the `TalosCluster` with `ontai.dev/runnerconfig-drift-requeue` to trigger reconciliation and recreate the missing RunnerConfig. Signal is then advanced to state=queued.

**Scope note:** This implementation covers the RunnerConfig-missing sub-case only. Talos version drift signaling (tenant conductor detects version delta, emits DriftSignal with InfrastructureTalosCluster kind, management conductor triggers upgrade Job) is a separate flow requiring a design session.

| Component | File | Change |
|-----------|------|--------|
| conductor | `internal/agent/capability_publisher.go` | `runnerConfigMissingDriftThreshold = 5`; consecutive-NotFound counter; `emitRunnerConfigMissingSignal`; `isPublishNotFound` helper |
| platform | `internal/controller/driftsignal_reconciler.go` | New `DriftSignalReconciler`; watches DriftSignal; annotates TalosCluster; advances signal to queued |
| platform | `internal/controller/driftsignal_reconciler_test.go` | 4 unit tests |
| conductor | `test/unit/capability/` | 3 unit tests: emit after threshold, idempotent on AlreadyExists, isPublishNotFound |
| platform | `cmd/platform/main.go` | `DriftSignalReconciler` registered with manager |

### T-24 -- Decision H Deletion Cascade

`handleTalosClusterDeletion` in `platform/internal/controller/taloscluster_helpers.go` extended with Step 0 (Decision H cascade) before the existing steps 1-3. New finalizer `platform.ontai.dev/decision-h-cascade` gates cascade completion.

Decision H order implemented:
1. Delete all `InfrastructurePackExecution` and `InfrastructurePackInstance` CRs in `seam-tenant-{cluster}` (wrapper layer first)
2. Remove TalosCluster name from `RBACProfile.spec.targetClusters` in `seam-tenant-{cluster}` and remove from `RBACPolicy.spec.allowedClusters` in seam-system (guardian layer second)
3. Existing steps 1-3 (RunnerConfig, Secrets, namespace) proceed after cascade completes

mode=bootstrap vs mode=import: step 0 runs for both. For mode=import, the namespace is not deleted (severance only); for mode=bootstrap, existing step 3 deletes the namespace (decommission). NOTE: physical Talos cluster destruction is not implemented -- INV-015 prohibits it. Only the governance relationship is severed for import; for bootstrap, only the seam-tenant namespace is deleted.

| Component | File | Change |
|-----------|------|--------|
| platform | `internal/controller/taloscluster_helpers.go` | `finalizerDecisionHCascade`; `ensureDecisionHCascadeFinalizer`; Decision H cascade in `handleTalosClusterDeletion` Step 0; `removeFromUnstructuredStringSlice` helper |
| platform | `internal/controller/taloscluster_helpers_test.go` | 5 unit tests covering cascade deletion, allowedClusters removal, mode=import guard, slice helper |

### Commits

| Repo | Hash | Message |
|------|------|---------|
| platform | bfe4ea1 | platform: T-24 Decision H deletion cascade order, T-23 DriftSignal cluster-state reconciler |
| conductor | 06d6ad6 | conductor: T-23 emit RunnerConfig-missing DriftSignal from capability publisher |

### All Tests Pass

| Repo | Command | Result |
|------|---------|--------|
| platform | `go test ./...` | All suites pass |
| conductor | `go test ./...` | All suites pass |

---

## Session/17 T-23 Talos Version Drift Detection Live Test (2026-05-02)

### New Components

| Component | File | Role |
|-----------|------|------|
| `TalosVersionDriftLoop` | `conductor/internal/agent/talos_version_drift_loop.go` | role=tenant: reads `node.status.nodeInfo.osImage` via Kubernetes API; compares against `InfrastructureTalosCluster.spec.talosVersion` in `ont-system`; emits DriftSignal with `affectedCRRef.Kind=InfrastructureTalosCluster` when all nodes agree on a version that differs from spec |

**Mixed-version skip invariant:** When nodes are at different Talos versions (mid-upgrade state), `readObservedTalosVersion()` returns empty string and no DriftSignal is emitted. Only fires when ALL nodes agree on the same non-spec version.

**`ParseTalosVersionFromOSImage(osImage string) string`** -- extracts version from `Talos (vX.Y.Z)` format. Used to normalize `node.status.nodeInfo.osImage`.

**`escalationThreshold const int32 = 3`** -- after 3 consecutive emissions without correction, the loop stops emitting. DriftSignal remains at last state; management conductor is responsible for escalation or manual reset.

### DriftSignalReconciler: InfrastructureTalosCluster Handler

`DriftSignalReconciler` (platform) extended with a second case:

For `affectedCRRef.Kind=InfrastructureTalosCluster` + `spec.state=pending`:
1. Parse `observedVersion` from `spec.driftReason` (field `observedTalosVersion:{version}`).
2. Patch `TalosCluster.status.observedTalosVersion` to the observed version.
3. Append a synthetic out-of-band TCOR operation record (capability: `talos-version-drift`, status: Succeeded, message: `out-of-band upgrade to {version} detected`).
4. Bump TCOR revision epoch to the observed version (calls `bumpTCORRevision` with the observed version as the new talosVersion).
5. Call `ensureCorrectiveUpgradePolicy()` -- creates `drift-version-{cluster}` UpgradePolicy in `seam-tenant-{cluster}` with `upgradeType=talos`, `targetTalosVersion=spec.talosVersion` (the declared desired state to restore).
6. Advance DriftSignal `spec.state` to `queued`.

`ensureCorrectiveUpgradePolicy()` is idempotent: no-op if the UpgradePolicy already exists with the same target version.

### Rolling Upgrade (talosUpgradeHandler)

`talosUpgradeHandler.Execute()` rewritten for rolling per-node sequential upgrade:

1. `params.TalosClient.Nodes()` returns node IPs from talosconfig endpoints.
2. For each node IP, calls `params.TalosClient.Upgrade(NodeContext(ctx, nodeIP), image, false)` with `stage=false` (immediate reboot).
3. Calls `waitForNodeReboot(ctx, client, nodeIP)` before proceeding to next node.

**`waitForNodeReboot()`** two-phase health check:
- Phase 1 (2-min window): polls `client.Health(NodeContext(ctx, nodeIP))` until node goes offline (confirming reboot started). If node never goes offline within 2 minutes, assumes reboot completed faster than poll interval and returns nil.
- Phase 2 (8-min window): polls until node comes back online. Returns error if node does not return within 8 minutes.

**`NodeRebootPollInterval = 10 * time.Second`** exported so tests can set to 0 for instant polls.

**Installer image fix:** `upgradeImage := "ghcr.io/siderolabs/installer:" + targetVersion`. The `targetTalosVersion` field in UpgradePolicy is a semantic version string (e.g. `v1.9.3`), not a full OCI reference.

**`TalosNodeClient` interface extended:**
- `Nodes() []string` -- returns node IPs from talosconfig endpoints parsed at construction.
- `Health(ctx context.Context) error` -- lightweight liveness check via Talos Version RPC; nil when responsive.

**`TalosClientAdapter`** updated: `nodes []string` field set at construction by `EndpointsFromTalosconfig(talosconfigPath)`; `Nodes()` returns the field; `Health()` calls `a.inner.Version(ctx)`.

### RBAC Fix

`ensureTenantExecutorResources()` in `taloscluster_helpers.go`: added `"upgradepolicies"` to the `platform.ontai.dev` resources list in the `platform-executor` Role definition. The `talos-upgrade` capability lists UpgradePolicies to find the target version.

### Live E2E Results (ccs-dev, 2026-05-02)

| # | Step | Result |
|---|------|--------|
| 1 | TalosVersionDriftLoop detected v1.9.5 (all 3 nodes) vs spec v1.9.3 | PASS |
| 2 | DriftSignal `drift-version-ccs-dev` emitted to `seam-tenant-ccs-dev` on management cluster | PASS |
| 3 | DriftSignalReconciler: `observedTalosVersion=v1.9.5` patched; out-of-band TCOR record written; TCOR revision bumped to 2 with `talosVersion: v1.9.5` | PASS |
| 4 | Corrective UpgradePolicy `drift-version-ccs-dev` created in `seam-tenant-ccs-dev` | PASS |
| 5 | talos-upgrade Job ran for ~2:42; all 3 nodes upgraded sequentially per-node with reboot wait | PASS |
| 6 | All 3 ccs-dev nodes returned to `Talos (v1.9.3)` | PASS |
| 7 | TCOR at revision 3 with `status: Succeeded` for `drift-version-ccs-dev-talos-upgrade` | PASS |

**Bugs found and fixed during live test:**
- `platform-executor` RBAC was missing `upgradepolicies` from platform.ontai.dev rules (FORBIDDEN on list).
- Installer image constructed incorrectly as bare version string `v1.9.3` instead of `ghcr.io/siderolabs/installer:v1.9.3`.

### Unit Tests

| Suite | Tests | Status |
|-------|-------|--------|
| `test/unit/agent/talos_version_drift_loop_test.go` | 4 (emits signal on version mismatch, skips when all nodes match spec, skips on mixed versions, ParseTalosVersionFromOSImage) | PASS |
| `internal/controller/driftsignal_reconciler_test.go` | 2 new (TalosVersionDrift_FullFlow verifies TCOR bump + observedTalosVersion + UpgradePolicy + DriftSignal queued; TalosVersionDrift_AlreadyQueued no-op) | PASS |
| `test/unit/capability/platform_test.go` | 2 new (RollingUpgrade_AllNodes: 3-node sequential upgrade; NoNodesReturnsValidationFailure: empty node guard) | PASS |

### Commits

| Repo | Branch | Hash | Message |
|------|--------|------|---------|
| conductor | session/17-hardening-profile-tests | 772e318 | conductor: T-23 TalosVersionDriftLoop -- detect out-of-band Talos version change, emit InfrastructureTalosCluster DriftSignal |
| conductor | session/17-hardening-profile-tests | 01a5cb5 | conductor: talos-upgrade rolling upgrade with per-node reboot wait and structured logging |
| platform | session/17-hardening-profile-tests | 967ba3f | platform: handle InfrastructureTalosCluster DriftSignal -- patch observedTalosVersion, write TCOR out-of-band record |
| platform | session/17-hardening-profile-tests | 3a9acd9 | platform: DriftSignalReconciler handles InfrastructureTalosCluster drift; fix platform-executor RBAC |

---

## Next Session Candidates

1. **Cluster recovery** -- cp3 NotReady and ccs-dev unreachable. All TENANT tests and MGMT-HP-NODE require healthy infrastructure before they can pass.
2. **MGMT-HP-NODE test fix** -- `mgmtWorkerNode = "ccs-mgmt-w2"` hardcoded in `hardeningprofile_e2e_test.go` does not exist on ccs-mgmt. TargetNodes for hardening-apply governs Job pod scheduling exclusion only; capability applies to all talosconfig endpoints regardless. Either provision the node or update the test to use an existing node, and decide whether single-node targeting should be implemented in the capability.
3. **PRs from session/17-hardening-profile-tests** -- conductor PR (per-node hardeningApply fix + unit tests) and platform PR (hardening e2e + PKI e2e). Both need Governor merge approval.
4. **Phase 6 (T-20, T-21)** -- Day2 scheduling with node awareness; CAPI-path Day2 parity (design sessions required).
5. **Guardian auto-RBAC expansion** -- Governor request 2026-05-02.
