# Seam Platform Architectural Gap Report and Task Sequence

**Authored:** 2026-04-24
**Governor decisions incorporated:** A, B, C, D, E, F, G, H, I (all open questions resolved)
**Status:** AUTHORIZED. Governor approval granted 2026-04-24. All approval gates in this document are pre-authorized. Implementation may proceed without blocking for further Governor sign-off on individual tasks.

---

## Governor Decisions (locked)

**Decision A -- OCI push client.**
The custom OCI Distribution Spec v2 HTTP client in `compile_oci_push.go` is accepted as-is. Do not rewrite to ORAS go library. Extract the OCI push logic behind a clean interface so a future ORAS replacement can be swapped in without touching Compiler command logic. Digest propagation to PackReceipt remains required regardless.

**Decision B -- helmVersion.**
`helmVersion` on a helm category PackBuild entry records which version of the Helm SDK was used to render the chart. Distinct from `chartVersion` (the chart's own version). Both are required for helm category entries. `helmVersion` ensures rendering reproducibility across SDK versions.

**Decision C -- Tenant cluster PermissionSnapshot and RBACPolicy.**
Conductor agent role=tenant is the author of both on tenant clusters. As part of its reconciliation loop, conductor agent role=tenant pulls the PermissionSnapshot and the tenant-scoped RBACPolicy from the management cluster and writes them into `ont-system` on the tenant cluster. The RBACPolicy written to `ont-system` is scoped to that tenant cluster specifically -- mirrored from the management cluster's record for that tenant -- not the full seam-system policy set.

**Decision D -- Mirror CRDs and TalosCluster on tenant cluster.**
ClusterPack, PackExecution, and PackInstance mirrors in `ont-system` on the tenant cluster are reconstructed synthetically by conductor agent role=tenant from PackReceipt data. Not federated or pulled from the management cluster. They exist to give local controllers on the tenant cluster visibility into desired state without requiring management cluster connectivity. When a TalosCluster is mode=import, the platform operator on the management cluster is responsible for projecting a read-only mirror of that TalosCluster CR into `ont-system` on the tenant cluster as part of its import reconciliation path.

**Decision E -- OperationsResult revision pattern.**
PackOperationResult uses a single-active-revision pattern with predecessor deletion, not an in-cluster append-log chain. When conductor writes a new revision: (1) write the new CR with incremented revision number, (2) dump the previous revision to the GraphQuery DB, (3) delete the previous revision CR. At any point exactly one active PackOperationResult exists per ClusterPack operation sequence. Schema must carry `revision` (int64), `previousRevisionRef` (string -- records what was deleted for GraphQuery chain reconstruction), and `talosClusterOperationResultRef` (string, stub, reserved for future cross-reference). Historical revisions live only in the GraphQuery DB.

**Decision F -- Universal seam-tenant namespace invariant.**
Guardian always writes RBACProfiles into `seam-tenant-{targetCluster}` regardless of whether `targetCluster` is a tenant cluster or the management cluster itself. The management cluster is also a tenant for ClusterPack deployment purposes. This convention is universal and must never be qualified by cluster role.

**Decision G -- Seam-core CRD authority invariant.**
All CRD schemas across the seam family are declared and owned exclusively by seam-core. Guardian, Platform, Wrapper, Conductor, Screen, and Vortex own only the status subresource fields within their declared reconciliation boundary on those CRDs. No operator defines or holds a CRD schema that another operator reconciles. This is an architectural invariant, not a convention. The functional forcing condition is T-18: conductor agent role=tenant must create ClusterPack, PackExecution, and PackInstance mirror CRDs in ont-system on tenant clusters. For conductor to write those objects, the CRD definitions must be installed on tenant clusters. If those CRDs remain in the wrapper repo, their installation is tied to wrapper deployment -- which does not run on tenant clusters. Moving them to seam-core, which is installed on every cluster as the foundational schema layer, resolves this cleanly. Any CRD currently defined in an individual operator repo that carries cross-operator contract semantics must be migrated to seam-core before Phase 5 work begins. RunnerConfig is a confirmed migration candidate: Platform and Wrapper both produce it while Conductor reconciles it.

**Decision I -- Drift signal acknowledgement chain.**
The conductor drift detection loop defined in Decision H is not complete without a three-state acknowledgement chain. The three states are: delivered, queued, and confirmed. When conductor role=tenant detects drift, it writes the drift reason into the affected CR status and creates a DriftSignal record in ont-system carrying a timestamp and a correlation ID. The DriftSignal state begins as pending. Management cluster conductor acknowledges receipt by writing back to that DriftSignal record through the federation channel, flipping its state from pending to delivered. If tenant conductor does not see a delivered acknowledgement within a configurable deadline, it re-emits the signal. This gives at-least-once delivery with no silent failures. When management conductor triggers corrective jobs through wrapper or platform, it writes the job reference back into the DriftSignal record and advances its state to queued. Tenant conductor can now confirm management has acted and identify what job was created. When the corrective job completes and the relevant CR status reflects the corrected state, tenant conductor reconciles, confirms drift is resolved, and closes the DriftSignal record by advancing its state to confirmed. If the job completed but drift persists, tenant conductor opens a new DriftSignal with an escalation counter incremented. After a configurable number of failed correction attempts, tenant conductor writes a terminal drift condition on the affected CR and stops re-emitting. Terminal drift conditions require human intervention. This is the Human-at-Boundary invariant in the remediation path -- automated correction has a defined retry ceiling and humans are the fallback, not an infinite retry loop. The federation channel must carry DriftSignal acknowledgement traffic in the management-to-tenant return direction alongside PermissionSnapshot and RBACProfile distribution already defined in T-17. All three return-direction traffic classes must be designed together in the T-17 design session.

---

## Gap Findings (post-decision)

### Area 1: TalosCluster Discriminator Matrix

Governor matrix:
- `mode=bootstrap, capi.enabled=false`: no role field written (implicit ont-native tenant)
- `mode=bootstrap, capi.enabled=true`: no role field written (implicit CAPI tenant)
- `mode=import`: role is mandatory (`management` or `tenant`)

Defects:
1. **CONFLICT** -- `TalosClusterSpec.Role` comment says "Required on the direct bootstrap path (capi.enabled=false)" -- the inverse of the correct invariant.
2. **WRONG** -- `compileBootstrap()` calls `clusterRole(in)` unconditionally and always writes Role in the CR, including for mode=bootstrap paths.
3. **MISSING** -- `readClusterInput()` has no validation that `mode=import` requires an explicit role. `clusterRole()` silently defaults to `management` when role is absent, regardless of mode.
4. **MISSING** -- No CEL validation rule on `TalosClusterSpec` enforcing that when `mode=import`, the `role` field must be present and must be one of `management` or `tenant`. Admission webhook must reject `mode=import` with absent or invalid role.

No schema-first dependency for compiler and comment fixes. T-04a (CEL validation in ontai-schema) must precede any platform webhook enforcement work.

### Area 2: PackReceipt and Helm Metadata Chain

All absent across the entire chain:

| Field | ClusterPack | PackExecution | PackInstance | PackReceipt |
|-------|-------------|---------------|--------------|-------------|
| chartVersion | ABSENT | ABSENT | ABSENT | ABSENT |
| chartURL | ABSENT | ABSENT | ABSENT | ABSENT |
| chartName | ABSENT | ABSENT | ABSENT | ABSENT |
| helmVersion | ABSENT | ABSENT | ABSENT | ABSENT |
| rbacDigest | present | N/A | N/A | ABSENT |
| workloadDigest | present | N/A | N/A | ABSENT |

Helm fields must be absent (omitempty, no default) for kustomize and raw categories. Decision 11 applies -- ontai-schema PRs first.

### Area 3: OCI Push and Digest Propagation

Decision A accepted the custom HTTP client. Remaining gaps: (1) the OCI push function must be extracted behind an interface (T-03), and (2) `rbacDigest` and `workloadDigest` produced by the Compiler are not carried to PackReceipt (T-10). T-10 is blocked until Area 2 schema tasks complete.

### Area 4: PackBuild Categories

Current: no `category` field, no kustomize path, no raw path. `HelmSource` pointer acts as implicit helm discriminator. `helmVersion` absent entirely.

Decision B clarifies helmVersion as Helm SDK version pin. Both `helmVersion` and `chartVersion` are required when category=helm.

### Area 5: PackOperationResult Revision Pattern

Decision E: single-active-revision with predecessor deletion. Schema must add `revision`, `previousRevisionRef`, `talosClusterOperationResultRef`. Write logic must change from upsert to revision-create-then-predecessor-delete. Wrapper PackExecutionReconciler must find latest revision by label/listing. Decision 11 applies -- ontai-schema PR first.

### Area 6: Tenant Cluster Namespace Gaps

Decisions C, D, and F assign authorship. All items blocked on tenant cluster availability (TENANT-CLUSTER-E2E backlog item). Note: `ont-system` must exist on the tenant cluster before any Phase 5 tasks can execute. Platform creates `ont-system` during import or bootstrap reconciliation. Verify platform behavior on this point before scheduling any Phase 5 work.

| Resource | Required location | Author (post-decision) | Status |
|---------|-------------------|------------------------|--------|
| PermissionSnapshot | tenant `ont-system` | conductor agent role=tenant (pull from mgmt) | BLOCKED |
| RBACPolicy (scoped) | tenant `ont-system` | conductor agent role=tenant (pull scoped copy from mgmt) | BLOCKED |
| conductor role=tenant RBACProfile | tenant `ont-system` | conductor agent role=tenant (pull from mgmt seam-tenant-{cluster}) | BLOCKED |
| ClusterPack mirror | tenant `ont-system` | conductor agent role=tenant (reconstruct from PackReceipt) | BLOCKED |
| PackExecution mirror | tenant `ont-system` | conductor agent role=tenant (reconstruct from PackReceipt) | BLOCKED |
| PackInstance mirror | tenant `ont-system` | conductor agent role=tenant (reconstruct from PackReceipt) | BLOCKED |
| TalosCluster (mode=import) | tenant `ont-system` | platform operator (management-side, remote write) | BLOCKED |

---

## Session Execution Constraints

These constraints apply to every session and every engineer working on this task list. Read before opening any branch.

- No Co-Authored-By trailers in any commit.
- No em dashes in any document or output.
- Branch naming: one branch per phase, named `session/phase{N}`. All tasks in that phase land on that branch across all repos. One PR per repo per phase.
  - session/phase0: T-01, T-02, T-03, T-04b, T-04c, T-04d (no-dependency tasks: conductor, platform, guardian, all repos)
  - session/phase1: T-04a, T-04, T-05, T-06 (schema PRs: ontai-schema)
  - session/phase2: T-07, T-08, T-09, T-10 (helm metadata chain: wrapper, conductor)
  - session/phase2b: T-2B-1 through T-2B-5 (seam-core CRD migration: ontai-schema, seam-core, conductor, wrapper, platform)
  - session/phase3: T-11, T-12, T-13 (PackBuild categories: conductor) -- blocked on Phase 2B completion
  - session/phase4: T-14, T-15, T-16 (revision pattern: seam-core, conductor, wrapper)
  - session/phase5: T-17, T-18, T-19 -- do not open until TENANT-CLUSTER-E2E closes and Phase 2B (seam-core migration) completes
  - session/phase6: T-20, T-21 -- do not open until design session completes
- One PR per repo per phase. The PR must reference the task IDs it covers (e.g., "implements T-07, T-08").
- Every new function, reconciler, struct field change, and persistence change must be accompanied by tests. Required test types per change:
  - Unit tests for all logic paths.
  - Integrity tests for schema field presence and serialization.
  - Smoke tests for the happy path of each capability.
  - Mock tests where external dependencies (OCI registry, cluster API) are involved.
  - Integration tests (envtest or real cluster) for reconciler and webhook behavior.
- ontai-schema PRs (T-04a, T-04, T-05, T-06) are their own PRs against the ontai-schema repo. They must merge before the operator implementation PRs that depend on them are opened.
- Live cluster testing sequence after all branches T-01 through T-16 are merged:
  1. WS8b: cert-manager Helm packbuild with three-bucket split on management cluster. This was pending during session/14.
  2. Full operator stack on management cluster: re-run all existing acceptance tests, confirm no regressions.
  3. Ont-native import tenant cluster (pre-created): onboard as tenant, run all testcases validated on management cluster.
  4. CAPI bootstrapped tenant cluster: repeat testcases from step 3.
  5. Ont-native bootstrap tenant cluster: repeat testcases from step 3.

---

## Sequenced Task List

Ordering rules enforced:
- Schema tasks (ontai-schema PRs) before any operator implementation that depends on them.
- Area 1 compiler and comment fixes, T-03, and T-04b have no schema-first dependency -- sequenced in Phase 0.
- Area 2 schema tasks (T-04) unlock Area 2 operator tasks and Area 3 digest propagation.
- Area 4 schema tasks (T-05) unlock Area 4 operator tasks.
- Area 5 schema task (T-06) unlocks Area 5 operator tasks.
- Area 6 tasks are a blocked group -- do not schedule until TENANT-CLUSTER-E2E closes.
- Phase 6 Day2 tasks are blocked -- do not schedule until design sessions complete.

### Phase 0 -- No-dependency tasks (implement immediately, no schema PR needed)

**T-01 -- Area 1: Compiler validation and CR emission fix (conductor)** COMPLETE 2026-04-24. PR #19 (conductor/session/area1).
- `readClusterInput()`: add validation refusing to proceed when `mode=import` and `role` is absent or not one of `management|tenant`.
- `clusterRole()`: make mode-aware; return an error when called for mode=import with empty role rather than silently defaulting.
- `compileBootstrap()` and both import paths: do NOT emit the `Role` field in the TalosCluster CR when mode=bootstrap (both capi and non-capi).
- Tests: unit tests covering mode=import-no-role (error), mode=bootstrap-capi-false (no role emitted), mode=bootstrap-capi-true (no role emitted), mode=import-management (role emitted), mode=import-tenant (role emitted).
- Branch: session/area1. Repo: conductor. File: `cmd/compiler/compile.go`.

**T-02 -- Area 1: Platform schema comment fix (platform)** COMPLETE 2026-04-24. PR #15 (platform/session/area1).
- Update `TalosClusterSpec.Role` field comment from "Required on the direct bootstrap path (capi.enabled=false)" to the correct invariant: role is absent on all bootstrap paths and mandatory on mode=import.
- Update the kubebuilder marker to reflect that role is only semantically meaningful on mode=import.
- No logic change in the reconciler. Comment and marker update only.
- Branch: session/area1. Repo: platform. File: `api/v1alpha1/taloscluster_types.go`.

**T-03 -- Area 3: OCI push interface extraction (conductor, Decision A)** COMPLETE 2026-04-24. Committed to conductor/session/phase0.
- Define an `OCIPushClient` interface with a single method matching the signature of `ociPushLayer()`.
- Wrap the existing HTTP implementation as the default concrete type behind this interface.
- `helmCompilePackBuild()` accepts the interface rather than calling `ociPushLayer()` directly.
- No behavioral change. Tests: unit test wiring the interface with a mock implementation to verify the call path.
- Branch: session/phase0. Repo: conductor. Files: `cmd/compiler/compile_oci_push.go`, `cmd/compiler/compile_packbuild_helm.go`.

**T-04b -- GUARDIAN-BL-RBACPROFILE-SWEEP: Guardian RBACProfile back-fill reconciler (guardian)** COMPLETE 2026-04-24. PR #14 (guardian/session/phase0).
- Implement a background reconciler in Guardian that runs on a configurable interval (default: 60s).
- Implementation: EnsurePackRBACProfileCRs exported from webhook package. RBACProfileBackfillRunnable scans seam-tenant-* namespaces; detects PermissionSet with missing RBACProfile; calls EnsurePackRBACProfileCRs. Registered via mgr.Add for role=management. RBAC_BACKFILL_INTERVAL env configures interval.
- Decision F applies: back-fill always targets `seam-tenant-{targetCluster}` regardless of cluster role.
- Tests: 6 unit tests in test/unit/controller/rbacprofile_backfill_test.go covering: no tenant namespaces, no PermissionSets, existing profile (no-op), missing profile (fill), namespace filtering, multi-cluster.
- Branch: session/phase0. Repo: guardian.

**T-04c -- Seam-core CRD ownership audit, migration manifest, and domain primitive mapping (all repos)** COMPLETE 2026-04-24. Audit document: CRD_OWNERSHIP_AUDIT.md on ontai/session/seam-core-audit. PR #10 (ontai root).
- Three-part audit document committed: Part 1 (CRD ownership audit across all repos), Part 2 (domain primitive derivation mapping for 5 migration candidates), Part 3 (ontai-schema gap list: 5 app-core entries, 5 seam-core entries, 2 infra deprecations).
- Migration candidates confirmed: RunnerConfig (conductor), PackReceipt (conductor), ClusterPack (wrapper), PackExecution (wrapper), PackInstance (wrapper).
- Additional confirmed candidate added by Decision I: DriftSignal. DriftSignal is written by conductor role=tenant and acknowledged by conductor role=management -- cross-operator contract, Decision G applies, must live in seam-core.
- All guardian, platform, and seam-core CRDs assessed as compliant.
- PackReceipt vs PackOperationResult merge decision required at start of migration session.
- Branch: session/seam-core-audit. Repos: ontai root.

**T-04d -- Seam-core CRD migration session scheduling (Governor gate -- PRE-AUTHORIZED 2026-04-24)** CLOSED 2026-04-25. Branch session/phase2b opened and executed. T-18 unblocked on this gate.
- Migration session executed on session/phase2b across seam-core, ontai-schema, conductor, wrapper, and platform repos.
- T-04d closes when the migration session branch is open and assigned. T-18 remains blocked until T-04d closes.
- Branch: session/phase2b (migration session branch; carries T-2B-1 through T-2B-9).

### Phase 1 -- Schema PRs (ontai-schema, must merge before dependent Phase 2, 3, 4 work begins)

**T-04a -- Area 1: TalosCluster CEL validation for mode=import (ontai-schema)**
- Add a CEL validation rule to the TalosCluster spec in `v1alpha1/platform/TalosCluster.json` enforcing: when `mode == "import"`, `role` must be present and must be one of `management` or `tenant`.
- A TalosCluster CR with `mode=import` and absent or invalid role must be rejected at admission.
- This closes the schema-side enforcement gap for Area 1 alongside the Compiler validation in T-01.
- PR: ontai-schema. No operator implementation dependency. Completes Area 1 schema work alongside T-02.

**T-04 -- Area 2 schema: helm metadata, helmVersion, and PackReceipt digests (ontai-schema)**
- Add to `v1alpha1/infra/ClusterPack.json`: `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional string, omitempty).
- Add to `v1alpha1/infra/PackExecution.json`: `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional string, omitempty).
- Add to `v1alpha1/infra/PackInstance.json`: `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional string, omitempty).
- Add to conductor-schema PackReceipt spec section: `rbacDigest`, `workloadDigest`, `chartVersion`, `chartURL`, `chartName`, `helmVersion` (all optional string, omitempty).
- Schema note: for kustomize and raw categories, all helm fields (`chartVersion`, `chartURL`, `chartName`, `helmVersion`) are absent by design (omitempty, no default value, no defaulting in schema).
- PR: ontai-schema. Blocks T-07, T-08.

**T-05 -- Area 4 schema: PackBuild category discriminator and helm fields (ontai-schema)**
- Add `category` field (enum: `helm`, `kustomize`, `raw`) to PackBuild schema.
- Add `helmVersion` field (string, required when category=helm) to the helm category entry.
- Document that `chartURL`, `chartVersion`, `chartName`, `helmVersion` are required when category=helm.
- Document that kustomize category requires a `kustomizePath` field (path to kustomize.yaml).
- Document that raw category requires pre-computed digests and no helm or kustomize fields.
- PR: ontai-schema. Blocks T-11.

**T-06 -- Area 5 schema: PackOperationResult revision fields (ontai-schema)**
- Add to PackOperationResult spec: `revision` (int64, required), `previousRevisionRef` (string, optional), `talosClusterOperationResultRef` (string, optional, stub reserved for future cross-reference).
- PR: ontai-schema. Blocks T-14.

### Phase 2 -- Operator implementation dependent on T-04 (helm metadata, helmVersion, PackReceipt digests)

**T-07 -- Area 2: wrapper type fields (wrapper)**
- Add `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` to `ClusterPackSpec`, `PackExecutionSpec`, `PackInstanceSpec`.
- All fields: optional, omitempty. No default values. Absent when category is not helm.
- Tests: unit tests verifying fields are absent when helmSource is not used; integrity test verifying serialization round-trip for all four fields.
- Branch: session/area2. Repo: wrapper. Files: `api/v1alpha1/clusterpack_types.go`, `packexecution_types.go`, `packinstance_types.go`.
- Blocked on T-04.

**T-08 -- Area 2 and Area 3: conductor runnerlib PackReceipt fields (conductor)**
- Add `RBACDigest`, `WorkloadDigest`, `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` to `PackReceiptSpec`.
- `rbacDigest` and `workloadDigest` are the durable OCI recovery anchors. `helmVersion` records the Helm SDK version used during rendering.
- All fields: optional. Absent when category is not helm (for chart fields) or when OCI split was not used (for digest fields).
- Tests: unit tests verifying struct field presence and serialization.
- Branch: session/area2. Repo: conductor. File: `pkg/runnerlib/packreceipt.go`.
- Blocked on T-04.

**T-09 -- Area 2: compiler writes chart metadata and helmVersion into ClusterPack CR (conductor)**
- In `helmCompilePackBuild()`: populate `ChartURL`, `ChartVersion`, `ChartName` in the emitted ClusterPack CR from `HelmSource.URL`, `HelmSource.Version`, `HelmSource.Chart` respectively.
- Populate `HelmVersion` from the embedded Helm SDK version (derive from the `helm.sh/helm/v3` module version in `go.mod` at build time, or embed as a build-time constant).
- For non-helm packbuild path: leave all four fields absent (omitempty).
- Tests: unit test verifying all four chart fields are populated in helm path and absent in non-helm path.
- Branch: session/area2. Repo: conductor. File: `cmd/compiler/compile_packbuild_helm.go`.
- Blocked on T-07 (wrapper type must have the fields).

**T-10 -- Area 2 and Area 3: conductor carry-through to PackReceipt (conductor)**
- In the wrapper capability (`internal/capability/wrapper.go`): read `RBACDigest`, `WorkloadDigest`, `ChartVersion`, `ChartURL`, `ChartName`, `HelmVersion` from the ClusterPack spec and write them into the PackReceipt when conductor agent acknowledges delivery.
- In `receipt_reconciler.go`: populate all six new fields on PackReceipt creation.
- Tests: unit tests verifying all six fields are carried through in the receipt write path. Mock test using a fake ClusterPack with chart metadata to verify end-to-end field propagation to PackReceipt.
- Branch: session/area2. Repo: conductor. Files: `internal/capability/wrapper.go`, `internal/agent/receipt_reconciler.go`.
- Blocked on T-08 (runnerlib type must have the fields) and T-09 (ClusterPack must carry chart fields).

### Phase 2B -- Seam-core CRD migration (MANDATORY before Phase 3)

Phase 2B completes Decision G: all cross-operator CRD schemas move to seam-core before the Compiler gains new output paths (kustomize, raw) in Phase 3. Phase 3 would deepen the Decision G violation if ClusterPack remains in wrapper when Phase 3 lands.

**T-2B-0 -- PackReceipt vs PackOperationResult merge decision (CLOSED 2026-04-24)**
Governor ruling: keep them separate. PackReceipt is written by the Conductor execute job after pack-deploy completes and carries rbacDigest, workloadDigest, and helm metadata. PackOperationResult is the management cluster append-log record written by the conductor wrapper capability and carries revision, previousRevisionRef, and operational status. Different writers, different lifecycles, different consumers.

Note on app-core: app-core is a future ONT application operator layer, not part of Phase 2B. The architectural chain domain-core -> app-core -> seam-core is canonical: every domain is application-first and every application is also a domain. app-core entries (AppBoundary, AppIdentity, etc.) already in index.json are correct and untouched. Phase 2B is a straight schema migration only.

**T-2B-1 -- ontai-schema PR 1: seam-core migration schemas for all wrapper and platform CRDs (ontai-schema)**
Add seven new seam-core schema files in one PR. Scope: all existing CRDs owned by wrapper and platform repos, plus conductor CRDs not yet in seam-core. Tracking: ontai-schema PR #7.
- `seam-core/InfrastructureClusterPack.json`: migrated from infra/ClusterPack. seam-core owner; wrapper creates, conductor signing loop updates status.
- `seam-core/InfrastructurePackExecution.json`: migrated from infra/PackExecution. seam-core owner; wrapper reconciler performs 4-gate check and submits Kueue Job.
- `seam-core/InfrastructurePackInstance.json`: migrated from infra/PackInstance. seam-core owner; present on management and tenant clusters.
- `seam-core/InfrastructurePackReceipt.json`: migrated from seam-core/PackReceipt. seam-core canonical form; supersedes interim PackReceipt entry. Spec sealed per INV-026.
- `seam-core/InfrastructureRunnerConfig.json`: no prior infra/ entry; source is conductor/pkg/runnerlib/runnerconfig.go. seam-core owner; platform operator authors exclusively per INV-009.
- `seam-core/InfrastructurePackBuild.json`: migrated from infra/PackBuild. seam-core owner; compiler input spec, never applied as a cluster CR.
- `seam-core/InfrastructureTalosCluster.json`: migrated from platform/TalosCluster. seam-core owner; platform operator reconciles instances.
Branch: session/phase2b. Repo: ontai-schema. Blocks T-2B-2.

**T-2B-2 -- ontai-schema PR 2: PackOperationResult cross-reference update (ontai-schema)**
Update `seam-core/PackOperationResult.json`: add `x-ont-depends-on` reference to InfrastructurePackReceipt reflecting the kept-separate decision from T-2B-0. No new fields; only the cross-reference annotation update.
Branch: session/phase2b. Repo: ontai-schema. Blocked on T-2B-1. Blocks T-2B-3.

**T-2B-3 -- ontai-schema PR 3: deprecation markers on superseded source schemas (ontai-schema)**
Add deprecation markers to existing source schema files that have been migrated to seam-core:
- `infra/ClusterPack.json`: add `x-ont-deprecated: true` and `x-ont-superseded-by: seam-core/InfrastructureClusterPack`.
- `infra/PackExecution.json`: add `x-ont-deprecated: true` and `x-ont-superseded-by: seam-core/InfrastructurePackExecution`.
- `infra/PackInstance.json`: add `x-ont-deprecated: true` and `x-ont-superseded-by: seam-core/InfrastructurePackInstance`.
- `infra/PackBuild.json`: add `x-ont-deprecated: true` and `x-ont-superseded-by: seam-core/InfrastructurePackBuild`.
- `platform/TalosCluster.json`: add `x-ont-deprecated: true` and `x-ont-superseded-by: seam-core/InfrastructureTalosCluster`.
Branch: session/phase2b. Repo: ontai-schema. Blocked on T-2B-2.

**T-2B-5 -- seam-core Go type additions (seam-core)**
After all three ontai-schema PRs (T-2B-1 through T-2B-3) merge, add Go type definitions to seam-core under `api/v1alpha1`. New files only -- do not remove anything from conductor, wrapper, or platform in this step.
- `runnerconfig_types.go` -- InfrastructureRunnerConfig matching seam-core schema exactly
- `clusterpack_types.go` -- InfrastructureClusterPack matching seam-core schema exactly
- `packexecution_types.go` -- InfrastructurePackExecution matching seam-core schema exactly
- `packinstance_types.go` -- InfrastructurePackInstance matching seam-core schema exactly
- `packreceipt_types.go` -- InfrastructurePackReceipt matching seam-core schema exactly
- `packbuild_types.go` -- InfrastructurePackBuild matching seam-core schema exactly
- `taloscluster_types.go` -- InfrastructureTalosCluster matching seam-core schema exactly
- `driftsignal_types.go` -- DriftSignal matching seam-core schema exactly. DriftSignal is written by conductor role=tenant and acknowledged by conductor role=management -- cross-operator contract, Decision G applies, must live in seam-core. Schema must cover: state enum (pending, delivered, queued, confirmed), correlationID, timestamp, affectedCRRef, driftReason, correctionJobRef, escalationCounter.
Full unit tests and serialization integrity tests required for each type.
Branch: session/phase2b. Repo: seam-core. Blocked on T-2B-3.

**T-2B-6 -- Conductor import migration (conductor)**
After T-2B-5 merges: remove RunnerConfig and PackReceipt Go type definitions from conductor. Update all conductor imports to seam-core/api/v1alpha1. All existing tests must pass.
Branch: session/phase2b. Repo: conductor. Blocked on T-2B-5.

**T-2B-7 -- Wrapper import migration (wrapper)**
After T-2B-6 merges: remove ClusterPack, PackExecution, PackInstance, and PackBuild Go type definitions from wrapper. Update all wrapper imports to seam-core/api/v1alpha1. All existing tests must pass.
Branch: session/phase2b. Repo: wrapper. Blocked on T-2B-6.

**T-2B-8 -- Platform import migration (platform)** COMPLETE 2026-04-25. PR #16 (platform/session/phase2b).
- Replaced platform's local TalosCluster struct hierarchy with Go type aliases to seam-core InfrastructureTalosCluster. GVK shifted from platform.ontai.dev/v1alpha1 to infrastructure.ontai.dev/v1alpha1.
- Replaced runnerconfig_cr.go AddKnownTypeWithName workaround with thin aliases to seam-core InfrastructureRunnerConfig. GVK shifted from runner.ontai.dev/v1alpha1 to infrastructure.ontai.dev/v1alpha1.
- Removed controller-gen-generated deepcopy stubs for alias types. Inlined 7 CAPIEnabled() call sites.
- Updated go.mod seam-core pin to fa4bedc (adds InfrastructureProvider enum, typed Origin, 6-field CAPIConfig, Phase/FailedStep on RunnerConfig status, all TalosCluster condition constants in seam-core/pkg/conditions).
- All 4 test packages pass: unit, integration, e2e (skipped cleanly), e2e/day2 (skipped cleanly).
Branch: session/phase2b. Repo: platform.

**T-2B-9 -- CRD manifest migration (seam-core, conductor, wrapper, platform)** COMPLETE 2026-04-25. PR #16 (platform/session/phase2b) + session/14-bake-lab-patches (conductor, wrapper).
- Platform done: removed platform.ontai.dev_talosclusters.yaml. Replaced integration test testdata with seam-core's infrastructure.ontai.dev_infrastructurerunnerconfigs.yaml.
- Conductor done: deleted runner.ontai.dev_runnerconfigs.yaml, runner.ontai.dev_packreceipts.yaml from config/crd. Migrated all dynamic GVR constants in signing_loop.go, receipt_reconciler.go, capability_publisher.go, packinstance_pull_loop.go, capability/wrapper.go, capability/guardian.go to infrastructure.ontai.dev with Infrastructure-prefixed resource names. Removed conductor/config/crd and wrapper/config/crd embed imports from compile_launch.go (seam-core covers all). Updated all conductor test files (unit, integration, e2e) to new GVKs.
- Wrapper done: deleted infra.ontai.dev_clusterpacks.yaml, infra.ontai.dev_packexecutions.yaml, infra.ontai.dev_packinstances.yaml from config/crd and config/crd/bases. Migrated all RBAC markers, annotation keys, label keys, finalizer, and GVK references in all three reconcilers to infrastructure.ontai.dev with Infrastructure-prefixed names. Updated all wrapper test files (unit, e2e) to new GVKs.
- Seam-core carries all infrastructure.ontai.dev_* CRD YAML files as authoritative source. No seam-core changes required.
- All six repos build clean. All conductor and wrapper unit tests pass (two fake-client Kind mapping fixes required for newWrapperDynClient and newThreeBucketDynClient; packinstance test scheme scoped to exclude InfrastructurePackReceipt from typed conversion to preserve conductor-written dynamic status fields).
Branch: session/phase2b (platform), session/14-bake-lab-patches (conductor, wrapper). Repos: seam-core (no change), conductor, wrapper, platform.

**Phase 2B completed 2026-04-25 (all items).** All GVK migrations complete across all repos. T-04d is closed. Phase 3 may proceed once Phase 1 schema PRs (T-04a, T-05) and Phase 2 helm metadata tasks (T-07 through T-10) are done.

### Phase 3 -- Operator implementation dependent on T-05 (PackBuild category)

**T-11 -- Area 4: PackBuildInput category field, helmVersion, and validation (conductor)**
- Add `Category string` field (enum: `helm`, `kustomize`, `raw`) to `PackBuildInput`.
- Add `HelmVersion string` field to `HelmSource` struct (records the Helm SDK version used for rendering; required when category=helm).
- Update `readPackBuildInput()` validation: all helm fields (`HelmSource`, `helmVersion`, `chartVersion`, `chartURL`, `chartName`) are validated as required only when `category=helm`. Return a descriptive error when `category=helm` and `helmVersion` is absent.
- Ensure raw and kustomize categories reject helm-specific fields.
- Tests: unit tests for all three category validation paths including absent-category error, helm-missing-helmVersion error, kustomize-with-helmSource error, raw-with-helmSource error.
- Branch: session/area4. Repo: conductor. File: `cmd/compiler/compile.go`.
- Blocked on T-05.

**T-12 -- Area 4: kustomize path implementation (conductor)**
- Add `KustomizeSource` struct to `PackBuildInput` with a `Path` field (path to the kustomize.yaml root directory).
- Implement `kustomizeCompilePackBuild()`: invoke the kustomize go client (`sigs.k8s.io/kustomize`) to render manifests from the given path; split rendered output into RBAC, cluster-scoped, and workload buckets using the existing `SplitManifests`; push three OCI layers; emit ClusterPack CR.
- Add kustomize go client dependency to `conductor/go.mod`.
- Tests: unit tests covering kustomize render invocation (with mock filesystem), manifest split, OCI push path. Smoke test with a minimal kustomize.yaml in a temp directory.
- Branch: session/area4. Repo: conductor. File: `cmd/compiler/compile_packbuild_kustomize.go` (new file).
- Blocked on T-05 and T-11.

**T-13 -- Area 4: raw path explicit category (conductor)**
- When `category=raw`: validate that no `HelmSource` or `KustomizeSource` fields are present; require pre-computed digests (`rbacDigest` and `workloadDigest`) or the legacy single `digest`; emit ClusterPack CR directly without any rendering step.
- The existing non-helmSource packbuild path becomes the canonical raw path once category is present.
- Tests: unit tests for raw validation (no helm/kustomize fields, digest required).
- Branch: session/area4. Repo: conductor. File: `cmd/compiler/compile.go`.
- Blocked on T-05 and T-11.

### Phase 4 -- Operator implementation dependent on T-06 (revision fields)

**T-14 -- Area 5: seam-core PackOperationResult type fields (seam-core)**
- Add `Revision int64`, `PreviousRevisionRef string`, `TalosClusterOperationResultRef string` to `PackOperationResultSpec`.
- `TalosClusterOperationResultRef` is a stub -- present in schema, always empty until TalosCluster OperationsResult is implemented. Its presence reserves the field name.
- Tests: unit tests verifying struct field presence, serialization, and that `TalosClusterOperationResultRef` defaults to empty string.
- Branch: session/area5. Repo: seam-core. File: `api/v1alpha1/packoperationresult_types.go`.
- Blocked on T-06.

**T-15 -- Area 5: conductor persistence single-active-revision write pattern (conductor)**
- Rewrite `WriteResult()` in `operationresult_writer.go` from upsert to single-active-revision-with-predecessor-deletion:
  1. List existing PackOperationResults in the namespace labelled by `ontai.dev/pack-execution={packExecutionRef}` to determine the current highest revision.
  2. Create a new CR named `pack-deploy-result-{packExecutionRef}-r{N+1}` with label `ontai.dev/pack-execution={packExecutionRef}`, `Revision = N+1`, `PreviousRevisionRef = name of the previous CR`.
  3. Dump the previous revision to the GraphQuery DB before deletion (log it at structured INFO level if GraphQuery DB is not yet wired, with the full spec as a JSON field for traceability).
  4. Delete the previous revision CR.
- Tests: unit tests for first write (revision=1, no predecessor, no delete), second write (revision=2, predecessor deleted), GraphQuery dump step (verify log output or stub DB call). Envtest integration test verifying that after two writes only one PackOperationResult CR exists in the namespace.
- Branch: session/area5. Repo: conductor. File: `internal/persistence/operationresult_writer.go`.
- Blocked on T-14.

**T-16 -- Area 5: wrapper PackExecutionReconciler reads latest revision (wrapper)**
- Update `PackExecutionReconciler` to find the current PackOperationResult by listing in the namespace filtered by label `ontai.dev/pack-execution={packExecutionName}` and selecting the entry with the highest `Revision`, rather than by fixed name.
- The fixed-name assumption breaks when revision numbers change the CR name.
- Tests: unit tests for list-by-label resolution with one result, multiple results (picks highest revision), no results (waits). Smoke test verifying the reconciler advances correctly after a revision update.
- Branch: session/area5. Repo: wrapper. File: `internal/controller/packexecution_reconciler.go`.
- Blocked on T-15.

### TENANT-CLUSTER-E2E: Found-and-Fixed Defects (pre-onboarding)

**Defect: Compiler conductorOp() hardcoded role=management for all enable bundles (FIXED 2026-04-26)**
- Root cause: `conductorOp()` in `compile_enable.go` had no `clusterRole` parameter; the string `"management"` was hardcoded in the pod annotation `platform.ontai.dev/role`. The downward API maps this annotation to the `CONDUCTOR_ROLE` env var, so every ccs-dev Conductor pod ran as management even after a ccs-dev enable bundle was applied.
- Impact: would have caused conductor agent on ccs-dev to execute management-mode reconciliation paths (drift correction jobs, corrective orchestration) instead of tenant-mode paths (pull loops, local write).
- Fix: added `clusterRole string` parameter to `conductorOp()` and `--cluster-role` CLI flag to `compiler enable`. ccs-dev enable bundle regenerated with `CONDUCTOR_ROLE=tenant`.
- Caught during: ccs-dev tenant cluster onboarding preparation, session/14-bake-lab-patches.
- conductor commit `e18cdf5`

### Phase 5 -- Blocked on TENANT-CLUSTER-E2E

Do not schedule these tasks until `TENANT-CLUSTER-E2E` backlog item is closed and a tenant cluster is available for integration testing. All tasks in this phase require live cluster access.

Prerequisite note: `ont-system` must exist on the tenant cluster before any Phase 5 tasks can execute. Platform creates `ont-system` during import or bootstrap reconciliation. Verify this behavior is correct and tested before scheduling Phase 5 work.

**T-17 (BLOCKED) -- Area 6: conductor agent role=tenant pull loops (conductor)**
- Implement pull loops in conductor agent role=tenant as part of its reconciliation loop. Three targets:
  1. PermissionSnapshot: connect to the management cluster, read the PermissionSnapshot for this tenant cluster from `seam-tenant-{tenantCluster}`, write it into `ont-system` on the tenant cluster. Update on each reconciliation cycle if the management cluster version is newer.
  2. Tenant-scoped RBACPolicy: read the RBACPolicy scoped to this tenant cluster from the management cluster, write it into `ont-system`. This is a subset of the full management cluster policy set, scoped to the records relevant to this tenant.
  3. RBACProfile for this cluster: read the RBACProfile for this tenant cluster from `seam-tenant-{tenantCluster}` on the management cluster and write it into `ont-system`. This is the return direction of the existing federation channel, which today carries only audit events from tenant to management and not governance data in the reverse direction.
- Federation channel design scope (Decision I): the design session for T-17 must account for three return-direction traffic classes through the federation channel: (a) PermissionSnapshot distribution, (b) RBACProfile distribution, and (c) DriftSignal acknowledgement writes from management conductor back to tenant conductor. All three must be designed in the same design session. The channel must provide ordering guarantees sufficient to prevent a stale acknowledgement from closing a newer DriftSignal.
- Design session required before implementation (CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION).
- Blocked on: TENANT-CLUSTER-E2E, design session, ont-system existence verified.

**T-18 (BLOCKED) -- Area 6: conductor agent role=tenant mirror CRD reconstruction (conductor)**
- Implement synthetic reconstruction in `ont-system` on the tenant cluster: after writing PackReceipt, reconstruct ClusterPack, PackExecution, and PackInstance CRs from PackReceipt data (Decision D).
- These are read-only mirrors. No operator on the tenant cluster should be permitted to modify them. Enforce via admission webhook or owner annotation.
- Design session required before implementation.
- Blocked on: TENANT-CLUSTER-E2E, design session, ont-system existence verified, T-04c (audit and mapping complete), T-04d (migration session open and branch assigned -- pre-authorized per Governor directive 2026-04-24, does not require a separate approval gate), and ontai-schema primitives confirmed or authored per T-04c part three output -- migrated CRDs must have their full domain primitive chain declared in ontai-schema before seam-core migration begins.

**T-19 (BLOCKED) -- Area 6: platform TalosCluster mode=import state machine and mirror projection (platform)**

Full import state machine:

State 1 -- Pending: TalosCluster CR created on management cluster with mode=import. Platform reconciler reads the kubeconfig secret referenced in spec. Writes TalosCluster condition ImportPending=True. No changes to tenant cluster.

State 2 -- Connecting: Platform reconciler establishes connectivity to the tenant cluster using the kubeconfig secret. Verifies ont-system namespace exists or creates it. Writes condition ImportConnecting=True, ImportPending=False.

State 3 -- Projecting: Platform reconciler writes a read-only mirror of the TalosCluster CR into ont-system on the tenant cluster. Mirror carries the management cluster's UID in an annotation (ontai.dev/management-uid) so tenant-side components can detect which management cluster governs them. Mirror is marked with label ontai.dev/mirror=true and an ownerReference back to the management cluster TalosCluster (by name, not UID -- the tenant cluster has no access to management cluster objects). Writes condition ImportProjected=True, ImportConnecting=False.

State 4 -- Ready: Guardian RBACProfile for the tenant cluster reaches provisioned=true on the management cluster (TENANT-CLUSTER-E2E onboarding gate). Platform writes condition ImportReady=True.

State 5 -- Severance (on TalosCluster deletion with mode=import): Teardown sequence per Decision H. After wrapper, guardian, and conductor components are torn down: platform removes the TalosCluster mirror from ont-system on the tenant cluster and removes the kubeconfig secret. The tenant cluster continues to run unchanged. Platform writes condition ImportSevered=True on the management cluster TalosCluster CR before the CR is deleted.

Mirror CR lifecycle:
- Created: State 3 transition.
- Updated: Any reconcile cycle where the management-cluster TalosCluster spec has changed since the mirror was last written. Reconciler computes a content hash of the spec and re-projects only when the hash differs.
- Deleted: State 5 severance path.

Design session required before implementation. T-19a must be designed in the same session.
- Blocked on: TENANT-CLUSTER-E2E, design session, ont-system existence verified.

**T-19a (BLOCKED) -- Area 6: guardian signing and distribution of tenant conductor RBACProfile (guardian, conductor)**

Gap: when conductor agent role=tenant starts on a tenant cluster, it must have an RBACProfile in ont-system on that cluster before it can begin its pull loops (T-17) or mirror reconstruction (T-18). Today no mechanism distributes the RBACProfile from management cluster seam-tenant-{cluster} to ont-system on the tenant cluster.

Sequence:
1. Management cluster guardian compiles RBACProfile for the conductor tenant component in seam-tenant-{tenantCluster} (already happens via enable bundle).
2. Guardian on management cluster signs the RBACProfile (existing signing infrastructure).
3. Conductor role=tenant pull loop (T-17) reads the signed RBACProfile from management cluster seam-tenant-{cluster} and writes it into ont-system on the tenant cluster.
4. The RBACProfile in ont-system carries the management cluster signature annotation. Any local admission on the tenant cluster must accept the pre-signed object without re-signing.
5. Guardian on the tenant cluster (role=observer, no compiler) validates the signature on admission but does not require a local PermissionSet.

Design question: does conductor role=tenant write the RBACProfile before or after its own RBAC gate is satisfied? If conductor cannot start until its RBACProfile is provisioned, there is a bootstrapping dependency. Resolution: the bootstrap RBAC window for the tenant cluster (INV-020) must cover the period before the tenant conductor RBACProfile is projected. Platform creates ont-system and writes a minimal service account for conductor during the import reconciliation path before conductor is deployed. Design session required.

Implementation dependencies: T-17 (pull loops), T-19 (platform import state machine), guardian signing loop.
- Blocked on: TENANT-CLUSTER-E2E, design session.

**T-22 (BLOCKED) -- Conductor drift detection reconciliation loop (conductor)**
- Implement the drift detection loop in conductor agent (both role=tenant and role=management). On each reconciliation cycle: compare actual deployed resources on the local cluster against the declared state held in the governance CRs (RBACPolicy, RBACProfile, PermissionSet, PackReceipt, TalosCluster). On any delta detected: write the drift reason into the relevant CR status field and emit a governance event signal to the management cluster. Conductor does not apply corrections directly. No remediation code lives in conductor.
- The loop is symmetric: role=tenant signals management; role=management handles corrective actions by triggering jobs through the normal operator paths.
- Acknowledgement chain (Decision I): the implementation must include the full three-state DriftSignal acknowledgement chain. On emit: create a DriftSignal CR in ont-system with state=pending, a timestamp, and a correlation ID. On management acknowledgement received: advance DriftSignal state to delivered. On corrective job creation by management: advance DriftSignal state to queued, record correctionJobRef. On drift resolved and CR status confirmed clean: advance DriftSignal state to confirmed and close the record. If job completes but drift persists: open a new DriftSignal with escalationCounter incremented. After a configurable escalation ceiling is reached: write a terminal drift condition on the affected CR and stop re-emitting. Terminal drift conditions require human intervention -- this is the Human-at-Boundary invariant in the remediation path.
- Re-emit deadline and escalation counter threshold must be configurable via conductor agent configuration (not hardcoded).
- Terminal drift condition must surface as a human-visible Condition entry on the affected CR with type=TerminalDrift and a message describing the affected resource and escalation count.
- DriftSignal is a new seam-core CR type: it is read and written by both conductor role=tenant and conductor role=management. Decision G applies. DriftSignal must be added to the seam-core CRD migration scope (T-2B-5) alongside the six confirmed candidates from T-04c. T-22 implementation cannot begin until DriftSignal is defined in seam-core.
- Design session required before implementation (CONDUCTOR-BL-DRIFT-DETECTION).
- Blocked on: TENANT-CLUSTER-E2E, Decision H design session, DriftSignal seam-core type defined (additional dependency on the seam-core migration session from T-04d).
- Repo: conductor.

**T-23 (BLOCKED) -- Management cluster corrective job triggering (wrapper, platform)**
- Implement the management-side response to drift signals received from tenant conductors. Two response paths:
  1. Pack redeployment: wrapper creates a new PackExecution or requeues an existing one in response to a pack drift signal from conductor.
  2. Cluster operations: platform creates or updates TalosCluster reconciliation targets in response to cluster state drift signals.
- Both paths must be idempotent: receiving the same drift signal twice must not result in duplicate Jobs or conflicting reconcile actions.
- Design session required before implementation.
- Blocked on: T-22, Decision H design session.
- Repos: wrapper, platform.

**T-24 (BLOCKED) -- Cluster deletion cascade and severance (platform, conductor)**
- Implement the fixed teardown sequence in conductor role=management when a governance CR (TalosCluster) is deleted from the management cluster. Teardown order is non-negotiable (Decision H):
  1. Wrapper components: delete PackInstance, PackExecution, RunnerConfig CRs for the cluster.
  2. Guardian components: delete RBACProfile, PermissionSet, RBACPolicy, PermissionSnapshot for the cluster.
  3. TalosCluster CR: delete last.
- Bootstrap vs import distinction derived from TalosCluster spec.mode field:
  - mode=bootstrap: permanent decommission. After teardown sequence completes, trigger infrastructure deprovision (platform destroys the cluster nodes).
  - mode=import: severance only. After teardown sequence completes, the cluster continues to exist but is no longer governed by ONT. No infrastructure action.
- Admit no variation from this order. Tests must verify the sequence is respected even when intermediate steps fail and are retried.
- Design session required before implementation.
- Blocked on: TENANT-CLUSTER-E2E, T-22, Decision H design session.
- Repos: platform, conductor.

**T-25a (BLOCKED) -- GUARDIAN-BL-RBACPROFILE-WEBHOOK: RBACProfile validation webhook (guardian)**

Gap: RBACProfile is absent from guardian's InterceptedKinds. No admission webhook intercepts RBACProfile creation or mutation on any cluster. The seam-operator label (ontai.dev/rbac-profile-type=seam-operator) is defined in guardian-schema.md to discriminate seam operator profiles from component profiles, but no webhook routing implements this today.

Required webhook behavior:
1. On RBACProfile admission: check for the ontai.dev/rbac-profile-type label.
2. If label value is seam-operator: validate that permissionDeclarations[].permissionSetRef references management-maximum only (CS-INV-008). Reject any seam-operator RBACProfile that references a PermissionSet other than management-maximum.
3. If label is absent or value is not seam-operator: route through the existing cluster policy validation path (permissionSetRef must reference a PermissionSet that exists in the same namespace).
4. On management cluster: block any RBACProfile write from a principal that is not the guardian manager service account or an authorized operator service account listed in the OperatorAuthority CRD.

Implementation: add RBACProfile to guardian webhook InterceptedKinds. Add a new webhook handler in the guardian webhook package that implements the two-path routing described above. Unit tests: 5 minimum (seam-operator with management-maximum: admit; seam-operator with other PS: reject; non-seam-operator with present PS: admit; non-seam-operator with absent PS: reject; non-seam-operator on wrong cluster: policy route).

This task has no TENANT-CLUSTER-E2E dependency. It is an independent guardian feature that improves admission safety on the management cluster.
- Blocked on: design session (short -- webhook routing logic is well-defined). May proceed in a near-term session.
- Repo: guardian.

**T-25b -- GUARDIAN-BL-RBACPROFILE-SWEEP: verify T-04b coverage (guardian)**

T-04b (COMPLETE 2026-04-24, guardian PR #14) implemented `RBACProfileBackfillRunnable` which scans seam-tenant-* namespaces and calls `EnsurePackRBACProfileCRs` for PermissionSets with missing RBACProfiles.

Gap check required: T-04b covers the case where a PermissionSet exists but the corresponding RBACProfile is absent. The GUARDIAN-BL-RBACPROFILE-SWEEP backlog item also describes RBAC resources arriving outside /rbac-intake/pack (bootstrap apply, kubectl apply, pre-split packs) with no corresponding RBACProfile at all.

Verification steps:
1. Confirm `EnsurePackRBACProfileCRs` handles the case where a PermissionSet exists with no corresponding RBACProfile (the T-04b path) -- covered.
2. Determine whether the sweep also handles raw RBAC objects (ClusterRole, ClusterRoleBinding) that exist in seam-tenant-* with no PermissionSet ancestor -- this was the secondary concern in the backlog item. If T-04b's runnable does not detect this case, a separate sweep reconciler is needed.
3. If step 2 confirms T-04b is sufficient: close GUARDIAN-BL-RBACPROFILE-SWEEP in BACKLOG.md and record the resolution.
4. If step 2 finds a gap: design a supplementary path and open a new task.

This is a verification task, not an implementation task. It requires reading `EnsurePackRBACProfileCRs` in `webhook/rbac_intake.go` and its callers.
- No blocking conditions. Assign to next guardian session.
- Repo: guardian.

### Phase 6 -- Day2 Operations. Blocked on TENANT-CLUSTER-E2E and CAPI-PATH-VERIFICATION

Day2 operations are uniform across management cluster, ont-native tenant clusters, and CAPI-path tenant clusters. The only distinction is a management-cluster-aware scheduling constraint described in T-20. Do not schedule these tasks until design sessions complete and CAPI-PATH-VERIFICATION backlog item is closed.

**T-20 (BLOCKED) -- Day2 operation scheduling with node awareness (platform)**
- Implement Day2 operation logic in the platform operator. Day2 operations cover node upgrades, Talos config updates, and maintenance cycles.
- The same logic applies to all cluster types (management, ont-native tenant, CAPI-path tenant) with one management-specific constraint: when performing Day2 operations on the management cluster, platform must first identify which nodes are currently hosting seam operator lease pods (by reading leader election leases in seam-system and tracing them to their pod and node). Nodes hosting active seam operator leases must be selected last in the operation sequence.
- Kueue Jobs created by platform for Day2 work must be scheduled with node affinity or anti-affinity rules that prevent those Jobs from landing on the node currently undergoing the operation, particularly for operations that involve node restarts.
- This management-cluster scheduling constraint does not apply when operating on tenant clusters where seam operators do not run.
- Design session required before implementation.
- Blocked on: TENANT-CLUSTER-E2E, design session.
- Repo: platform.

**T-21 (BLOCKED) -- CAPI-path Day2 parity verification (platform)**
- Verify that the Day2 operation path exercised for ont-native clusters via TalosCluster reconciliation also reaches CAPI-managed tenant clusters using the same code path.
- The node-awareness rules from T-20 apply to any CAPI-path cluster that hosts seam components.
- Identify and eliminate any branch divergence found between ont-native and CAPI-path Day2 handling.
- Design session required before implementation.
- Blocked on: CAPI-PATH-VERIFICATION backlog item, design session.
- Repo: platform.

---

## Task Dependency Graph (summary)

```
Phase 0 (no deps):
  T-01  (Area 1, compiler validation + CR emission)   -- no deps
  T-02  (Area 1, platform comment fix)                -- no deps
  T-03  (Area 3, OCI push interface extraction)       -- no deps
  T-04b (guardian RBACProfile back-fill reconciler)   -- no deps
  T-04c (seam-core CRD ownership audit)               -- no deps, blocks T-04d
  T-04d (migration session scheduling -- PRE-AUTHORIZED) -- after T-04c, blocks T-18

Phase 1 (schema PRs, no deps within list):
  T-04a (ontai-schema: TalosCluster CEL mode=import)  -- no deps, completes Area 1
  T-04  (ontai-schema: helm metadata + helmVersion)   -- no deps, blocks T-07 T-08
  T-05  (ontai-schema: PackBuild category)            -- no deps, blocks T-11
  T-06  (ontai-schema: revision fields)               -- no deps, blocks T-14

Phase 2 (after T-04):
  T-07  (wrapper: chart + helmVersion fields)         -- after T-04, blocks T-09
  T-08  (conductor runnerlib: receipt fields)         -- after T-04, blocks T-10
  T-09  (compiler: chart + helmVersion write)         -- after T-07, blocks T-10
  T-10  (conductor: carry-through to PackReceipt)     -- after T-08 T-09

Phase 2B (after T-07 through T-10 merge; mandatory before Phase 3):
  T-2B-0 (merge decision: keep PackReceipt separate)          -- CLOSED 2026-04-24
  T-2B-1 (ontai-schema: 7 seam-core Infrastructure* schemas)  -- COMPLETE 2026-04-24 (PR #7)
  T-2B-2 (ontai-schema: PackOperationResult cross-reference)  -- COMPLETE 2026-04-24 (PR #7)
  T-2B-3 (ontai-schema: deprecation markers on 5 sources)     -- COMPLETE 2026-04-24 (PR #7)
  T-2B-5 (seam-core: 7 Go type additions + conditions pkg)    -- COMPLETE 2026-04-25 (seam-core/main, commit fa4bedc)
  T-2B-6 (conductor: import migration)                        -- COMPLETE 2026-04-24 (conductor/session/phase2b)
  T-2B-7 (wrapper: import migration)                          -- COMPLETE 2026-04-24 (wrapper/session/phase2b)
  T-2B-8 (platform: import migration + TalosCluster)          -- COMPLETE 2026-04-25 (platform PR #16)
  T-2B-9 (CRD manifest migration: all repos complete)          -- COMPLETE 2026-04-25 (platform PR #16 + session/14-bake-lab-patches); closes T-04d

Phase 3 (after T-05 AND Phase 2B complete):
  T-11  (conductor: PackBuildInput category + helmVersion) -- after T-05 + Phase 2B, blocks T-12 T-13
  T-12  (conductor: kustomize path)                   -- after T-11
  T-13  (conductor: raw path)                         -- after T-11

Phase 4 (after T-06):
  T-14  (seam-core: revision fields)                  -- after T-06, blocks T-15
  T-15  (conductor: single-active-revision write)     -- after T-14, blocks T-16
  T-16  (wrapper: revision-aware result read)         -- after T-15

Phase 5 (BLOCKED -- TENANT-CLUSTER-E2E):
  T-17   (conductor: tenant pull loops x3)              -- TENANT-CLUSTER-E2E + design
  T-18   (conductor: mirror CRD reconstruction)         -- TENANT-CLUSTER-E2E + design + T-04c + seam-core migration session
  T-19   (platform: TalosCluster mode=import state machine + mirror)  -- TENANT-CLUSTER-E2E + design
  T-19a  (guardian/conductor: tenant conductor RBACProfile distribution) -- TENANT-CLUSTER-E2E + T-17 + T-19 + design
  T-22   (conductor: drift detection + DriftSignal ack chain)      -- TENANT-CLUSTER-E2E + Decision H design session + DriftSignal seam-core type
  T-23   (wrapper/platform: management corrective job triggering)  -- after T-22 + Decision H design session
  T-24   (platform/conductor: cluster deletion cascade + severance) -- after T-22 + TENANT-CLUSTER-E2E + Decision H design session
  T-25b  (guardian: verify T-04b covers GUARDIAN-BL-RBACPROFILE-SWEEP) -- no blocking conditions; assign to next guardian session

  Note: T-22, T-23, T-24 blocked on TENANT-CLUSTER-E2E and Decision H design session; T-23 additionally blocked on T-22; T-24 additionally blocked on T-22. DriftSignal seam-core type must be added to seam-core before T-22 implementation begins.

No-cluster guardian work:
  T-25a  (guardian: RBACProfile validation webhook)    -- design session only; no TENANT-CLUSTER-E2E dependency

Phase 6 (BLOCKED -- TENANT-CLUSTER-E2E + CAPI-PATH-VERIFICATION):
  T-20  (platform: Day2 node-aware scheduling)        -- design session required
  T-21  (platform: CAPI-path Day2 parity)             -- CAPI-PATH-VERIFICATION + design
```

---

## Live Cluster Testing Sequence (after T-01 through T-16 are merged)

1. WS8b: cert-manager Helm packbuild with three-bucket split on the management cluster. This was held during session/14 pending VPN/docker access. Run first to confirm the three-bucket path works end-to-end before any new work is tested.
2. Full acceptance suite on management cluster: re-run all existing acceptance tests across guardian, platform, wrapper, conductor, seam-core. Confirm no regressions from T-01 through T-16.
3. Ont-native import tenant cluster (pre-created, no bootstrap): onboard as a tenant, run all testcases validated on the management cluster.
4. CAPI bootstrapped tenant cluster: repeat testcases from step 3.
5. Ont-native bootstrap tenant cluster: repeat testcases from step 3.

Phase 5 (T-17 through T-19) and Phase 6 (T-20 through T-21) work begins only after step 3 is confirmed stable.

---

## Closure Instructions

Tasks T-01 through T-16 are the active implementation sequence. T-17 through T-21 are blocked on tenant cluster availability, CAPI path verification, and design sessions.

When tasks T-01 through T-16 are all closed, remove the GAP_TO_FILL.md pointer comment from PROGRESS.md. Do not delete this file until T-17 through T-21 are also resolved or formally moved to BACKLOG.md with their blocking conditions recorded there.
