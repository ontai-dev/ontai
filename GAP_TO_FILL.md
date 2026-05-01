# Seam Platform: Open Work and Remaining Tasks

**Last updated:** 2026-05-01
**Original authored:** 2026-04-24. Cleaned up 2026-05-01 -- completed tasks removed; open tasks updated to reflect session/15 state.
**Governor decisions incorporated:** A, B, C, D, E, F, G, H, I (all locked)
**Status:** AUTHORIZED. All approval gates pre-authorized 2026-04-24.

---

## Locked Governor Decisions (reference only)

**Decision A** -- OCI push client: custom HTTP client accepted as-is; must be extractable behind an interface (T-03 complete).
**Decision B** -- `helmVersion` on PackBuild records Helm SDK version; distinct from `chartVersion`.
**Decision C** -- Conductor agent role=tenant pulls PermissionSnapshot and scoped RBACPolicy from management cluster and writes to `ont-system`.
**Decision D (revised 2026-04-30)** -- PackReceipt is the sole local desired-state reference on tenant clusters. No mirror ClusterPack, PackExecution, or PackInstance CRs on tenant clusters. T-18 closed obsolete.
**Decision E** -- PackOperationResult uses single-active-revision pattern. Predecessor labeled `ontai.dev/superseded=true` and retained (max 10). No deletion of predecessor.
**Decision F** -- Guardian always writes RBACProfiles into `seam-tenant-{targetCluster}` regardless of cluster role.
**Decision G** -- seam-core is the exclusive owner of all cross-operator CRD schemas. Phase 2B complete.
**Decision H** -- Conductor is the drift detection authority. No direct remediation. Three-state DriftSignal chain (pending/queued/confirmed). Bootstrap vs import deletion distinction via TalosCluster spec.mode.
**Decision I** -- DriftSignal acknowledgement chain carries three traffic classes through federation: PermissionSnapshot, RBACProfile, DriftSignal acks.

---

## Session Execution Constraints

- No Co-Authored-By trailers. No em dashes.
- Branch naming: one branch per phase. `session/phase{N}` for schema tasks; feature branches for new items.
- One PR per repo per phase. PR must reference task IDs.
- Every new function, struct field, and persistence change requires tests (unit + integrity + smoke + mock/integration as applicable).
- Schema PRs (ontai-schema) must merge before dependent operator implementation PRs are opened.

---

## Current Open Task List

### Phase 1 -- Schema PRs (ontai-schema, no operator dependencies)

These four schema PRs have no dependencies on each other and can be opened in parallel. They are the blockers for all Phase 2, 3, and 4 work.

**T-04a -- TalosCluster CEL validation for mode=import (ontai-schema)**
- Add CEL validation rule to TalosCluster spec: when `mode == "import"`, `role` must be present and must be one of `management` or `tenant`.
- Rejects mode=import with absent or invalid role at admission.
- Completes Area 1 schema enforcement. Compiler validation (T-01) already done; this closes the CRD-level gate.

**T-04 -- Helm metadata + helmVersion + PackReceipt digests (ontai-schema)**
- Add to ClusterPack, PackExecution, PackInstance specs: `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional, omitempty).
- Add to PackReceipt spec: `rbacDigest`, `workloadDigest`, `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional, omitempty).
- Helm fields absent by design for kustomize and raw categories (no defaulting in schema).
- Blocks: T-07, T-08.

**T-05 -- PackBuild category discriminator (ontai-schema)**
- Add `category` field (enum: `helm`, `kustomize`, `raw`) to PackBuild schema.
- Add `helmVersion` (required when category=helm) to helm category.
- Document required fields per category.
- Blocks: T-11.

**T-06 -- PackOperationResult revision fields (ontai-schema)**
- Add to PackOperationResult spec: `revision` (int64, required), `previousRevisionRef` (string, optional), `talosClusterOperationResultRef` (string, optional, stub).
- Note: Decision E revised the original pattern -- predecessors are retained with `ontai.dev/superseded=true`, not deleted. Schema must support the label-based listing pattern.
- Blocks: T-14.

---

### Phase 2 -- Operator impl: helm metadata chain (blocked on T-04)

**T-07 -- Wrapper: chart + helmVersion fields (wrapper)**
- Add `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` to `ClusterPackSpec`, `PackExecutionSpec`, `PackInstanceSpec`.
- All optional, omitempty. Tests: round-trip serialization for all four fields; absent when helmSource not used.
- Blocked on T-04.

**T-08 -- Conductor runnerlib: PackReceipt fields (conductor)**
- Add `RBACDigest`, `WorkloadDigest`, `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` to `PackReceiptSpec` in `pkg/runnerlib/packreceipt.go`.
- Blocked on T-04.

**T-09 -- Compiler: write chart metadata into ClusterPack CR (conductor)**
- In `helmCompilePackBuild()`: populate `ChartURL`, `ChartVersion`, `ChartName` from HelmSource; populate `HelmVersion` from embedded SDK version constant.
- Non-helm paths: leave all four fields absent (omitempty).
- Blocked on T-07 (wrapper type must have fields).

**T-10 -- Conductor: carry helm + digest fields through to PackReceipt (conductor)**
- In `internal/capability/wrapper.go`: read `RBACDigest`, `WorkloadDigest`, `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` from ClusterPack spec and write to PackReceipt on conductor agent acknowledgement.
- In `internal/agent/receipt_reconciler.go`: populate all six new fields on PackReceipt creation.
- Blocked on T-08 (runnerlib type) and T-09 (ClusterPack must carry chart fields).

---

### Phase 3 -- Operator impl: PackBuild categories (blocked on T-05)

**T-11 -- Conductor: PackBuildInput category field and validation (conductor)**
- Add `Category string` (enum: `helm`, `kustomize`, `raw`) to `PackBuildInput`.
- Add `HelmVersion string` to `HelmSource` struct.
- Update `readPackBuildInput()`: helm fields validated as required only when `category=helm`. Reject cross-category field contamination.
- Tests: unit tests for all three category validation paths.
- Blocked on T-05.

**T-12 -- Conductor: kustomize packbuild path (conductor)**
- Add `KustomizeSource` struct with `Path` field (path to kustomize.yaml root).
- Implement `kustomizeCompilePackBuild()`: invoke kustomize go client, split output via `SplitManifests`, push three OCI layers, emit ClusterPack CR.
- Add kustomize go client to `conductor/go.mod`.
- New file: `cmd/compiler/compile_packbuild_kustomize.go`.
- Blocked on T-05 and T-11.

**T-13 -- Conductor: raw packbuild explicit category (conductor)**
- When `category=raw`: validate no HelmSource or KustomizeSource present; require pre-computed digests or legacy single digest.
- The existing rawSource path becomes canonical for `category=raw`. `compile_packbuild_raw.go` already implements this; wire the category discriminator.
- Tests: validation error for raw with helm/kustomize fields present.
- Blocked on T-05 and T-11.

---

### Phase 4 -- Operator impl: PackOperationResult revision pattern (blocked on T-06)

Note: Decision E revised -- predecessors are retained with `ontai.dev/superseded=true`, not deleted. The seam-core conductor `fdfa63d` commit already implements retention. T-14 through T-16 need the schema fields to be formally present.

**T-14 -- seam-core: PackOperationResult revision fields (seam-core)**
- Add `Revision int64`, `PreviousRevisionRef string`, `TalosClusterOperationResultRef string` to `PackOperationResultSpec`.
- `TalosClusterOperationResultRef` is a stub field (always empty until future cross-reference is implemented).
- Tests: struct field presence, serialization round-trip.
- Blocked on T-06.

**T-15 -- Conductor: confirm revision persistence matches schema (conductor)**
- Verify the existing `fdfa63d` retention implementation aligns with the schema fields added in T-14.
- If field names or types diverge, update to match schema.
- Tests: existing persistence tests already cover retention behavior; add tests asserting `Revision`, `PreviousRevisionRef` are populated correctly.
- Blocked on T-14.

**T-16 -- Wrapper: revision-aware PackOperationResult lookup (wrapper)**
- Update `PackExecutionReconciler` to find current POR by listing with label `ontai.dev/pack-execution={packExecutionName}` and selecting highest `Revision` -- not by fixed name.
- Tests: unit tests for list-by-label with one result, multiple results (picks highest revision), no results (waits).
- Blocked on T-15.

---

### Phase 5 -- Tenant cluster work (TENANT-CLUSTER-E2E now unblocked -- ccs-dev operational)

**T-17 -- Conductor tenant pull loops: remaining items (conductor)**

The PermissionSnapshot pull loop is COMPLETE (TenantSnapshotRunnable in guardian, session/15). The conductor-tenant RBACProfile distribution (guardian side) is COMPLETE (guardian PR #18, session/15). Remaining:
- Implement conductor role=tenant pull loop for the conductor-tenant RBACProfile: connect to management cluster, read the RBACProfile from `seam-tenant-{cluster}`, write to `ont-system` on tenant cluster. This is tracked as CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION in PROGRESS.md.
- Implement the scoped RBACPolicy pull: read the RBACPolicy scoped to this tenant cluster from management cluster, write to `ont-system`. Federation channel design session required for ordering guarantees (Decision I: three traffic classes must be designed together).
- Design session: CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION.

**T-23 (PARTIAL) -- Management corrective job triggering: platform path only (platform)**

The wrapper pack redeployment path is COMPLETE -- DriftSignalHandler in conductor deletes PackExecution to retrigger, session/15 e2e verified. Remaining:
- Platform path: when a cluster-state drift signal arrives at management conductor (TalosCluster drift, RunnerConfig drift), platform must create or update reconciliation targets to initiate corrective action.
- This is the non-pack side of Decision H: cluster operations path for drift-driven correction.
- Design session required. No implementation until design is approved.
- Repo: platform.

**T-24 -- TalosCluster deletion cascade and severance (platform, conductor)**

Note: ClusterPack/orphan teardown on conductor side is COMPLETE (session/15 `f9f73e4`). Wrapper DriftSignal cleanup on ClusterPack deletion is COMPLETE (session/15 `e431629`). Remaining: the full TalosCluster-level teardown sequence per Decision H (non-negotiable order: wrapper components → guardian components → TalosCluster CR).

- Implement TalosCluster deletion coordinator in conductor role=management: when governance CR deleted from management cluster, execute teardown in order: (1) delete PackInstance, PackExecution, RunnerConfig for the cluster; (2) delete RBACProfile, PermissionSet, RBACPolicy, PermissionSnapshot for the cluster; (3) delete TalosCluster CR last.
- Implement mode distinction: `mode=bootstrap` triggers infrastructure decommission (platform destroys nodes); `mode=import` severs management relationship only (cluster continues running).
- Tests must verify teardown order is respected even when intermediate steps fail and are retried.
- Design session required.
- Repos: platform, conductor.

**T-25a -- Guardian RBACProfile validation webhook (guardian)**

No TENANT-CLUSTER-E2E dependency. Independent guardian feature.
- Add RBACProfile to guardian webhook `InterceptedKinds`.
- Two-path routing: if `ontai.dev/rbac-profile-type=seam-operator` label present, validate that `permissionDeclarations[].permissionSetRef` references `management-maximum` only (CS-INV-008); reject any seam-operator profile referencing another PermissionSet. Otherwise route through cluster policy validation.
- Block any RBACProfile write from non-authorized principals on management cluster.
- Unit tests: 5 minimum (seam-operator+management-maximum: admit; seam-operator+other: reject; non-seam+present PS: admit; non-seam+absent PS: reject; unauthorized principal: reject).
- No design session required -- logic is well-defined.
- Repo: guardian.

---

### Phase 6 -- Day2 scheduling (BLOCKED -- design session required)

**T-20 -- Day2 operation scheduling with node awareness (platform)**
- Day2 operations on management cluster: identify which nodes host active seam operator lease pods; schedule those nodes last in the operation sequence.
- Kueue Jobs for Day2 work must carry node affinity/anti-affinity rules preventing Jobs from landing on the node currently undergoing the operation.
- Management cluster constraint does not apply to tenant cluster Day2 ops.
- Blocked on: design session (CAPI-PATH-VERIFICATION backlog).
- Repo: platform.

**T-21 -- CAPI-path Day2 parity verification (platform)**
- Verify Day2 operation path for CAPI-managed tenant clusters matches the ont-native path.
- Identify and eliminate branch divergence.
- Blocked on: CAPI-PATH-VERIFICATION backlog item, design session.
- Repo: platform.

---

## New Open Items (from session/15, not previously tracked)

**GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING (guardian) -- COMPLETE**
- `reconcileTenantSnapshotPath()` added. Profiles with empty RBACPolicyRef take tenant path: skip ceiling validation, check local mirrored PermissionSnapshot, set Provisioned=True. TenantProfileRunnable clears RBACPolicyRef. Guardian commit 693ba7d. Live validation on ccs-dev: PENDING (requires rebuilt image deploy).

**CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION (conductor)**
- Conductor role=tenant must pull the conductor-tenant RBACProfile from `seam-tenant-{cluster}` on the management cluster and write it into `ont-system` on the tenant cluster.
- Guardian side complete (PR #18). Conductor pull loop not yet implemented.
- Feeds into T-17 remaining items.

**PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE (platform)**
- `ensureWrapperRunnerResources` in `taloscluster_helpers.go` creates wrapper-runner SA/Role/RoleBinding/ClusterRoleBinding at tenant onboarding. No corresponding cleanup on TalosCluster deletion.
- Add cleanup to TalosCluster deletion path: delete ClusterRoleBinding `wrapper-runner-{cluster}` as part of tenant offboarding sequence.
- Repo: platform.

**CLUSTERPACK-BL-VERSION-CLEANUP (conductor, seam-core)**
- PackReceipt must carry a full resource inventory (GVK + name + namespace per deployed resource) as a spec field.
- When a new PackInstance version arrives on the tenant cluster, conductor role=tenant must diff the old PackReceipt inventory against new PackInstance manifests and delete orphaned resources (present in old receipt, absent in new manifests).
- Prevents resource stranding when components are removed between pack versions.
- Requires seam-core schema addition to PackReceipt spec, then conductor drift loop update.
- Repos: seam-core (schema), conductor (drift loop).

**CONDUCTOR-BL-SIGNING-KEY-TENANT (conductor) -- COMPLETE**
- `--signing-private-key` and `--output-public-key` flags added to compiler enable. INV-026 enforced: `--signing-private-key` rejected when `--cluster-role=tenant`. ccs-dev enable bundle updated: private key removed from Deployment env and signing-key Secret. Conductor commit 7563ebe.

---

## Open Task Dependency Graph

```
Phase 1 (schema PRs, parallel):
  T-04a  (ontai-schema: TalosCluster CEL mode=import)     -- no deps
  T-04   (ontai-schema: helm metadata + PackReceipt digests) -- no deps, blocks T-07 T-08
  T-05   (ontai-schema: PackBuild category)               -- no deps, blocks T-11
  T-06   (ontai-schema: POR revision fields)              -- no deps, blocks T-14

Phase 2 (after T-04):
  T-07   (wrapper: chart + helmVersion fields)            -- after T-04, blocks T-09
  T-08   (conductor runnerlib: receipt fields)            -- after T-04, blocks T-10
  T-09   (compiler: chart metadata write)                 -- after T-07, blocks T-10
  T-10   (conductor: carry fields to PackReceipt)         -- after T-08 T-09

Phase 3 (after T-05):
  T-11   (conductor: category field + validation)         -- after T-05, blocks T-12 T-13
  T-12   (conductor: kustomize path)                      -- after T-11
  T-13   (conductor: raw path explicit category)          -- after T-11

Phase 4 (after T-06):
  T-14   (seam-core: POR revision fields)                 -- after T-06, blocks T-15
  T-15   (conductor: revision persistence alignment)      -- after T-14, blocks T-16
  T-16   (wrapper: revision-aware POR lookup)             -- after T-15

Phase 5 (TENANT-CLUSTER-E2E unblocked; design sessions pending):
  T-17   (conductor: remaining tenant pull loops)         -- design session
  T-23   (platform: cluster-state drift corrective jobs)  -- after T-22 complete + design session
  T-24   (platform/conductor: TalosCluster deletion cascade) -- design session

No-cluster dependencies:
  T-25a  (guardian: RBACProfile validation webhook)       -- design session only (short)

New items (no ordering dependency):
  GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING            -- COMPLETE (guardian 693ba7d)
  CONDUCTOR-BL-SIGNING-KEY-TENANT                        -- COMPLETE (conductor 7563ebe)
  CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION      -- feeds T-17 remaining
  PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE              -- independent
  CLUSTERPACK-BL-VERSION-CLEANUP                         -- seam-core schema first

Phase 6 (design sessions required):
  T-20   (platform: Day2 node-aware scheduling)          -- CAPI-PATH-VERIFICATION + design
  T-21   (platform: CAPI-path Day2 parity)               -- CAPI-PATH-VERIFICATION + design
```

---

## Live Cluster Testing Sequence (T-01 through T-16 must be merged first)

The following items are already complete and do NOT need re-testing:
- Basic pack deploy, upgrade, rollback, redeploy on ccs-mgmt (session/13, session/14)
- Drift detection + DriftSignal full cycle on ccs-dev (session/15)
- ClusterPack deletion + orphan teardown on ccs-dev (session/15)
- Guardian role=tenant on ccs-dev (session/15)

Remaining live cluster testing:
1. **WS8b**: cert-manager Helm packbuild with three-bucket split on management cluster. Confirm three-bucket split path works with a Helm-compiled ClusterPack (cert-manager was deployed to ccs-dev, not ccs-mgmt via helm path). Verify all PackReceipt fields populated correctly.
2. **T-04a validation gate**: After schema PR merges, confirm that applying a TalosCluster with `mode=import` and absent role is rejected at admission on both clusters.
3. **Phase 2 regression**: After T-07 through T-10 merge, verify PackReceipt carries correct helm metadata fields end-to-end for a Helm-source ClusterPack.
4. **Phase 3 smoke**: After T-11 through T-13 merge, run a kustomize-category packbuild on the ccs-mgmt cluster to confirm the kustomize rendering + OCI push path works.
5. **Phase 4 regression**: After T-14 through T-16 merge, verify PackOperationResult `revision` and `previousRevisionRef` are populated on pack-deploy and that wrapper's label-based lookup finds the correct POR.
6. **GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING**: After fix, verify cert-manager and kube-system RBACProfiles reach `provisioned=true` on ccs-dev without a local cluster-policy.

Phase 5 (T-17, T-23, T-24) and Phase 6 (T-20, T-21) live testing begins only after their respective design sessions complete and implementation is merged.

---

## Closure Instructions

Remove this file when all tasks above are closed or formally moved to BACKLOG.md. The CONTEXT.md priority block referencing this file must be deleted at the same time.

Tasks T-04a through T-16 are the active implementation sequence (schema PRs first, then operator impl). New items from session/15 are the next-session priority for the `GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING` item.
