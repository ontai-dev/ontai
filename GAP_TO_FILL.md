# Seam Platform: Open Work and Remaining Tasks

**Last updated:** 2026-05-02
**Original authored:** 2026-04-24. Audited against codebase 2026-05-01 -- all tasks verified at file/function level.
**Governor decisions incorporated:** A, B, C, D, E, F, G, H, I (all locked)
**Status:** AUTHORIZED. All approval gates pre-authorized 2026-04-24.

---

## Locked Governor Decisions (reference only)

**Decision A** -- OCI push client: custom HTTP client accepted as-is; must be extractable behind an interface (T-03 complete).
**Decision B** -- `helmVersion` on PackBuild records Helm SDK version; distinct from `chartVersion`.
**Decision C** -- Conductor agent role=tenant pulls PermissionSnapshot and scoped RBACPolicy from management cluster and writes to `ont-system`.
**Decision D (revised 2026-04-30)** -- PackReceipt is the sole local desired-state reference on tenant clusters. No mirror ClusterPack, PackExecution, or PackInstance CRs on tenant clusters. T-18 closed obsolete.
**Decision E** -- PackOperationResult uses single-active-revision pattern. Predecessor labeled `ontai.dev/superseded=true` and retained (max 10). No deletion of predecessor.
**Decision F** -- Guardian(role=management) always writes RBACProfiles into `seam-tenant-{targetCluster}` regardless of cluster role.
**Decision G** -- seam-core is the exclusive owner of all cross-operator CRD schemas. Phase 2B complete.
**Decision H** -- Conductor is the drift detection authority. No direct remediation. Three-state DriftSignal chain (pending/queued/confirmed). Bootstrap vs import deletion distinction via TalosCluster spec.mode.
**Decision I** -- DriftSignal acknowledgement chain carries three traffic classes through federation: PermissionSnapshot, RBACProfile, DriftSignal acks.

---

## Session Execution Constraints

- No Co-Authored-By trailers. No em dashes.
- Branch naming: one branch per phase. `session/phase{N}` for schema tasks; feature branches for new items.
- One PR per repo per phase. PR must reference task IDs.
- Every new function, struct field, and persistence change requires tests (unit + integrity + smoke + mock/integration as applicable).

---

## Verified-Complete Tasks (closed by codebase audit 2026-05-01)

The following tasks were listed as open but are confirmed complete by direct code inspection:

| Task | Evidence |
|------|----------|
| T-04 (helm metadata fields) | `chartVersion`, `chartURL`, `chartName`, `helmVersion` present on all four types in `seam-core/api/v1alpha1/`: clusterpack_types.go L104-116, packexecution_types.go L36-48, packinstance_types.go L75-87, packreceipt_types.go L55-67 |
| T-06 (POR revision fields) | `Revision int64`, `PreviousRevisionRef string`, `TalosClusterOperationResultRef string` in `seam-core/api/v1alpha1/packoperationresult_types.go` L106-122; present in CRD YAML |
| T-07 (wrapper chart fields) | Wrapper has no own API types (`wrapper/api/v1alpha1/` contains only `.gitkeep`). Wrapper consumes seam-core types directly. Fields present in seam-core. Task complete. |
| T-08 (runnerlib PackReceipt fields) | Fields in `InfrastructurePackReceiptSpec` (seam-core owns schema per Decision G). `pkg/runnerlib/packreceipt.go` is a stub; actual carry-through implemented in `conductor/internal/agent/packinstance_pull_loop.go` `buildReceiptSpecPayload()` L268-296. |
| T-09 (compiler chart metadata) | `helmCompilePackBuild()` in `conductor/cmd/compiler/compile_packbuild_helm.go` L252-255 populates `ChartURL`, `ChartVersion`, `ChartName`, `HelmVersion`. Raw path (`compile_packbuild_raw.go`) correctly omits (no chart for raw packs by design). |
| T-10 (carry-through to PackReceipt) | `packinstance_pull_loop.go` `buildReceiptSpecPayload()` reads chart fields from PackInstance artifact JSON and writes to PackReceipt when present. `rbacDigest`/`workloadDigest` written by `capability/wrapper.go` `writePackReceipt()` L934. |
| T-14 (POR revision fields seam-core) | All three fields confirmed in `seam-core/api/v1alpha1/packoperationresult_types.go` L106-122 and CRD YAML. |
| T-15 (conductor revision persistence) | `conductor/internal/persistence/operationresult_writer.go`: `Revision` set at L114, `PreviousRevisionRef` at L115, superseded label at L166, pruning at L185-216 (max 10). |
| T-16 (wrapper revision-aware POR lookup) | `findLatestPOR()` in `wrapper/internal/controller/packexecution_reconciler.go` L1158-1184 lists by `ontai.dev/pack-execution` label and selects highest `Revision`. Called at L466. |
| GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING | `reconcileTenantSnapshotPath()` in `guardian/internal/controller/rbacprofile_controller.go`. Guardian commit 693ba7d. |
| CONDUCTOR-BL-SIGNING-KEY-TENANT | Compiler `--signing-private-key` flag rejects when `--cluster-role=tenant`. ccs-dev bundle: private key removed. Conductor commit 7563ebe. |

---

## Current Open Task List

### Phase 1 -- Schema PRs (ontai-schema)

**T-04a -- CLOSED.** CEL rule `self.mode != 'import' || (has(self.role) && self.role != '')` confirmed present in CRD YAML at line 291. No code change required.

**T-05 -- CLOSED.** `Category string` added to `PackBuildInput`. Cross-contamination validation in `readPackBuildInput`. Category-driven dispatch in `compilePackBuild`. 6 unit tests. conductor session/15-capability-tests d2f117b.

---

### Phase 3 -- PackBuild categories (CLOSED)

**T-11 -- CLOSED.** `HelmVersion string` added to `HelmSource`. Cross-category contamination validated in `readPackBuildInput`. 6 unit tests. conductor session/15-capability-tests d2f117b.

**T-12 -- CLOSED.** `KustomizeSource` struct and `kustomizeCompilePackBuild()` in `compile_packbuild_kustomize.go`. Uses krusty (INV-014). kustomizeSource early return in validation. 3 unit tests. conductor session/15-capability-tests 47aff29.

**T-13 -- CLOSED.** Category-driven dispatch in `compilePackBuild` (switch on `in.Category`). Raw path only when `category=raw`. Backward-compatible nil-check retained. conductor session/15-capability-tests d2f117b.

---

### Phase 5 -- Tenant cluster work

**T-17 -- CLOSED.** All five conductor role=tenant pull loops now present: SnapshotPullLoop, PackInstancePullLoop, PackReceiptDriftLoop, RBACProfilePullLoop (conductor-tenant), RBACPolicyPullLoop (cluster-policy). Both new loops wired in `kernel/agent.go`. 4 unit tests each. conductor session/15-capability-tests 6d9009f.

**T-23 (PARTIAL) -- Management corrective job triggering: platform path (platform)**

Current state: `conductor/internal/agent/drift_signal_handler.go` handles pack-drift DriftSignals (deletes PackExecution to retrigger pack-deploy). This is the conductor side. Platform has ZERO DriftSignal handling: grep of `platform/internal/controller/` returns no matches for `DriftSignal`. The platform path (cluster-state drift: TalosCluster or RunnerConfig drift triggers corrective platform action) is unimplemented.

Design question: should platform watch DriftSignals directly, or should conductor role=management call platform via some other signal? Design session required before implementation.

**T-24 -- TalosCluster deletion cascade (platform, conductor)**

Current state: `platform/internal/controller/taloscluster_helpers.go` `handleTalosClusterDeletion()` covers:
- (1) RunnerConfig deletion in `ont-system`
- (2) kubeconfig + talosconfig Secrets deletion
- (3) Tenant namespace (`seam-tenant-{name}`) deletion

Not covered (Decision H order is non-negotiable):
- PackInstance, PackExecution deletion (wrapper layer) BEFORE namespace deletion
- RBACProfile, PermissionSet, RBACPolicy, PermissionSnapshot deletion (guardian layer)
- TalosCluster CR deletion last
- mode distinction: `mode=bootstrap` → infra decommission; `mode=import` → severance only

The current deletion also means conductor role=tenant on the tenant cluster becomes orphaned (its `InfrastructureTalosCluster` copy in `ont-system` disappears when `seam-tenant-{name}` is deleted, but conductor keeps running). Manual conductor Deployment deletion on the tenant cluster is required today. Design session required for the coordinator.

**T-25a -- CLOSED.** RBACProfile added to InterceptedKinds. Gate 4a validates seam-operator profiles reference management-maximum only. 5 unit tests. guardian session/15-capability-tests (prior session).

---

### Phase 6 -- Day2 scheduling (BLOCKED -- design session required)

**T-20 -- Day2 operation scheduling with node awareness (platform)**
- Day2 ops on management cluster: schedule nodes hosting active seam operator lease pods last.
- Kueue Jobs must carry node affinity/anti-affinity preventing landing on the node under operation.
- Blocked: design session.

**T-21 -- CAPI-path Day2 parity verification (platform)**
- Verify Day2 operation for CAPI-managed clusters matches the ont-native path.
- Blocked: CAPI-PATH-VERIFICATION backlog + design session.

---

## New Open Items

**CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION -- CLOSED.** `RBACProfilePullLoop` in `rbacprofile_pull_loop.go`. conductor session/15-capability-tests (prior session).

**PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE -- CLOSED.** `finalizerWrapperRunnerCRBCleanup` + Step 3 in `handleTalosClusterDeletion`. Fake-client bug fixed. platform session/15-capability-tests (prior session).

**CLUSTERPACK-BL-VERSION-CLEANUP -- CLOSED.** `deleteOrphanedResources()` + `deployedResourceKey()` in `packinstance_pull_loop.go`. `buildReceiptSpecPayload` converts `[]map[string]interface{}` to `[]interface{}` to avoid unstructured deep-copy panic. 2 unit tests. conductor session/15-capability-tests 409e3f2.

---

## Open Task Dependency Graph (2026-05-02)

All previously active items closed. Remaining open items require design sessions or are Phase 6.

```
Design session required (Phase 5):
  T-23   (platform: cluster-state drift corrective jobs)   -- design session
  T-24   (platform/conductor: TalosCluster deletion cascade) -- design session

Phase 6 (excluded by directive -- design sessions required):
  T-20   (platform: Day2 node-aware scheduling)            -- CAPI-PATH-VERIFICATION + design
  T-21   (platform: CAPI-path Day2 parity)                 -- CAPI-PATH-VERIFICATION + design
```

---

## Live Cluster Testing Sequence

Already validated (do NOT re-test):
- Pack deploy, upgrade, rollback, redeploy on ccs-mgmt (session/13, session/14)
- Drift detection + DriftSignal full cycle on ccs-dev (session/15)
- ClusterPack deletion + orphan teardown on ccs-dev (session/15)
- Guardian role=tenant on ccs-dev (session/15)

Remaining:
1. **WS8b**: cert-manager Helm packbuild three-bucket split on management cluster. Verify all PackReceipt helm metadata fields populated.
2. **T-04a gate**: After CEL rule added, confirm mode=import with absent role rejected at admission.
3. **Phase 3 smoke**: After T-11 through T-13, run kustomize-category packbuild on ccs-mgmt.
4. **GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING live gate**: Rebuild guardian image, deploy to ccs-dev, verify cert-manager RBACProfile reaches `provisioned=true` without local cluster-policy.

---

## Closure Instructions

Remove this file when all tasks above are closed or formally moved to BACKLOG.md. The CONTEXT.md priority block referencing this file must be deleted at the same time.
