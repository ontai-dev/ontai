# ONT Platform Progress

**Last updated:** April 26, 2026 (session/15 import-wiring)

**Current state:** Phase 2B complete. Three-layer RBAC hierarchy locked (CS-INV-008). T-19 and T-19a implemented -- platform drives full conductor state machine for tenant import; guardian provisions conductor-tenant RBACProfile. PRs platform #17 and guardian #18 open. Import/bootstrap mode architecture corrected (session/15-import-wiring): compiler no longer emits seam-tenant namespace; Platform creates it on CR admission (CP-INV-004). Next gate: TENANT-CLUSTER-E2E (ccs-dev onboarding, awaiting Governor).

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

## Open Work

### Blocking Alpha

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev onboarding. Phase B script ready. Promotes all AC-2, AC-4, AC-5 e2e stubs to live. T-19 and T-19a now implemented. Awaiting Governor. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull conductor-tenant RBACProfile from seam-tenant-{cluster} on management cluster and write it into ont-system on the tenant cluster. Guardian side complete (PR #18 pending). Conductor pull loop not yet implemented. |

### Next Session

| ID | Component | Description |
|----|-----------|-------------|
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | Add RBACProfile validation webhook; route seam-operator label profiles through management-maximum validation. |
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | No reconciler back-fills RBACProfiles for RBAC arriving outside rbac-intake. Governor design session required. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | ConductorReady gate polls RunnerConfig on 30s requeue. Should watch RunnerConfig status and trigger immediately on capability publication. |

---

## Next Session Candidates

1. **TENANT-CLUSTER-E2E** -- ccs-dev onboarding (awaiting Governor acknowledgement).
