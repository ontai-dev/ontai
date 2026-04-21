# ONT Platform Progress

**Current state:** session/13-clusterpack-rbac-split WS1-WS10 COMPLETE. Full 6-step split path verified end-to-end on ccs-mgmt.
**Full history:** PROGRESS-archive-2026-04-20.md

---

## Branch Summary

### session/13-clusterpack-rbac-split (conductor, wrapper, guardian, ontai-schema -- WS1-WS8 complete, stop at WS8)

**Role:** Platform Engineer + Schema Engineer.

**Governor ruling:** wrapper-runner ClusterRole from session/13-clusterpack-apply-fixes WS7 is the WRONG fix. Pack-deploy must use guardian intake for RBAC (INV-004). Session replaces it with the two-layer OCI artifact contract.

**WS1 -- Branch creation and baseline (CLOSED):** All three repos branched to session/13-clusterpack-rbac-split from main.

**WS2 -- Schema amendments (CLOSED):**
- ontai-schema PR #2 merged: `ClusterPack.json` with `rbacDigest` and `workloadDigest` fields.
- `wrapper/docs/wrapper-schema.md` amended: `rbacDigest`/`workloadDigest` fields, two-layer OCI artifact contract section.

**WS3 -- Compiler packbuild split (CLOSED):**
- `conductor/internal/packbuild/split.go`: `ParseManifests` and `SplitRBACAndWorkload` pure functions.
- `conductor/cmd/compiler/compile_packbuild_split.go`: re-exports from cmd/compiler.
- `conductor/cmd/compiler/compile.go`: `RBACDigest`/`WorkloadDigest` in `PackBuildInput` and `compilePackBuild`.
- 6 unit tests in `conductor/test/unit/compiler/packbuild_split_test.go`. All pass.
- Commit: `feat: compiler packbuild splits RBAC and workload into separate OCI layers`

**WS4 -- wrapper ClusterPack types (CLOSED):**
- `wrapper/api/v1alpha1/clusterpack_types.go`: `RBACDigest` and `WorkloadDigest` on `ClusterPackSpec`.
- `make generate` run; CRD YAML regenerated.

**WS5 -- Guardian /rbac-intake/pack endpoint (CLOSED):**
- `guardian/internal/webhook/rbac_pack_intake_handler.go`: new `RBACPackIntakeHandler` at `/rbac-intake/pack`. Accepts YAML manifests with `componentName` + `targetCluster`. Stamps `ontai.dev/rbac-owner=guardian` and applies via SSA. INV-004.
- `guardian/internal/webhook/server.go`: `RegisterPackIntake` method added.
- 7 unit tests in `guardian/test/unit/webhook/rbac_pack_intake_test.go`. All pass.
- Commit: `feat: guardian /rbac-intake/pack endpoint for ClusterPack RBAC layer intake`

**WS6 -- pack-deploy split path (CLOSED):**
- `conductor/internal/capability/clients.go`: `GuardianIntakeClient` interface (`SubmitPackRBACLayer`, `WaitForRBACProfileProvisioned`). `GuardianClient` field on `ExecuteClients`.
- `conductor/internal/capability/wrapper.go`: `executeSplitPath` method for two-layer OCI artifact. `ensureNamespaces` function added. Legacy path unchanged for backward compatibility.
- 6 unit tests in `conductor/test/unit/capability/pack_deploy_split_test.go`. All pass.
- Commit: `feat: pack-deploy routes RBAC through guardian intake before workload apply`

**WS7 -- wrapper-runner Role tightened (CLOSED):**
- `conductor/cmd/compiler/compile_enable.go`: removed `rbac.authorization.k8s.io` rule from wrapper-runner Role. Added workload kinds: `persistentvolumeclaims`, `endpoints`, `pods`, `replicasets`, `ingresses`, `ingressclasses`, `jobs`, `cronjobs`, `horizontalpodautoscalers`.
- Commit: `fix: tighten wrapper-runner Role to workload resources only`

**WS8 -- Full suite pass (CLOSED):**
- conductor: all unit tests PASS. go vet PASS.
- guardian: all unit tests PASS. go vet PASS.
- wrapper: all unit tests PASS. go vet PASS.

**WS9-WS10 -- Cluster apply, nginx split-path e2e (CLOSED 2026-04-21):**
- Images rebuilt from merged main (wrapper, conductor, guardian). Enable bundle applied (new seam-core-crds, conductor-deployment, wrapper-runner, MutatingWebhookConfiguration). Old wrapper-runner ClusterRole/CRB deleted from cluster. Operators restarted.
- Nginx two-layer OCI artifacts pushed. nginx-v3.yaml compiled with rbacDigest/workloadDigest. ClusterPack applied.
- Root causes found and fixed (3 sessions): GuardianIntakeClientAdapter wired in conductor execute mode; guardian webhook registrations (RegisterRBACIntake, RegisterPackIntake, RegisterOperatorCRGuard, RegisterDeclaringPrincipal) added to main.go; rbac_pack_intake_handler.go creates PermissionSet/RBACPolicy/RBACProfile in tenant-{targetCluster} after applying RBAC manifests; tenant-ccs-mgmt namespace added to enable bundle; wrapper-runner-rbacprofile-reader Role/RB added to tenant-ccs-mgmt; wrapper-runner-ns-creator ClusterRole/CRB added for cross-namespace workload deployment.
- Full 6-step split path verified: pull-rbac-layer PASS, rbac-intake PASS, wait-rbac-profile PASS (RBACProfile provisioned=true), pull-workload-layer PASS, ensure-namespaces PASS, apply-workload PASS. PackExecution Succeeded=True.
- Key architectural confirmation: management cluster (ccs-mgmt) is treated as tenant for operations -- uses seam-tenant-ccs-mgmt (pack delivery) and tenant-ccs-mgmt (guardian security CRs) namespaces identically to tenant clusters.

---

### session/12-lineage-schema-amendment (seam-core, platform, wrapper, guardian, ontai-schema -- in progress, awaiting Governor push)

**Role:** Schema Engineer + Controller Engineer.

**Four Governor-approved schema amendments:**
1. `declaringPrincipal` added to `rootBinding` (stamps identity from declaring-principal annotation).
2. `createdAt` and `actorRef` added to every `descendantRegistry` entry.
3. `outcomeRegistry` as new append-only terminal outcome section in ILI spec.
4. `lineageIndexRef` in guardian audit records correlates events to governing ILI.

**WS1 -- Branch creation:** All 5 repos branched to session/12-lineage-schema-amendment from main.

**WS2 -- domain-core schema amendment (CLOSED):**
docs/domain-core-schema.md amended: `declaringPrincipal`, `createdAt`, `actorRef`, `outcomeRegistry`.
Commit: `governor: amend DomainLineageIndex schema -- declaringPrincipal, createdAt, actorRef, outcomeRegistry`

**WS3 -- seam-core schema amendment (CLOSED):**
docs/seam-core-schema.md amended with same four fields. Declaration 6 added: outcomeRegistry terminal closure protocol.
Commit: `governor: amend InfrastructureLineageIndex schema to inherit session/12 DomainLineageIndex amendments`

**WS4 -- guardian schema amendment (CLOSED):**
docs/guardian-schema.md: new §17 Audit Record Schema with AuditEvent table including lineageIndexRef.
Commit: `governor: amend guardian audit record schema -- add lineageIndexRef`

**WS5 -- ontai-schema JSON Schema (CLOSED):**
InfrastructureLineageIndex.json: declaringPrincipal, createdAt, actorRef, outcomeRegistry, OutcomeEntry defs.
AuditEvent.json: new schema file with LineageIndexRef.
ontai-schema PR #1 raised (session/12 branch pushed, PR open).

**WS6 -- seam-core Go types (CLOSED):**
`api/v1alpha1/infrastructurelineageindex_types.go`: DeclaringPrincipal on RootBinding, CreatedAt+ActorRef on DescendantEntry (RecordedAt renamed), OutcomeType enum, OutcomeEntry struct, OutcomeRegistry field.
`api/v1alpha1/zz_generated.deepcopy.go`: OutcomeEntry deep copy methods added.
Commit: `session/12: add declaringPrincipal, createdAt, actorRef, outcomeRegistry to ILI types`

**WS7 -- guardian webhook (CLOSED):**
`internal/webhook/declaring_principal_handler.go`: DeclaringPrincipalHandler stamps annotation on CREATE for all 9 root-declaration kinds. Skips during bootstrap window (INV-020). RFC 6901 JSON patch.
`internal/webhook/server.go`: RegisterDeclaringPrincipal method added.
5 unit tests in `test/unit/webhook/declaring_principal_test.go`.
Commit: `session/12: guardian declaring-principal MutatingWebhook stamps annotation on root declaration CREATE`

**WS8 -- seam-core controller changes (CLOSED):**
`internal/controller/lineage_controller.go`: buildILI reads declaring-principal annotation, populates rootBinding.declaringPrincipal. Fallback "system:unknown".
`internal/controller/descendant_reconciler.go`: actorRef resolved from ILI.declaringPrincipal (authoritative), falls back to LabelActorRef label.
`internal/controller/outcome_reconciler.go`: new OutcomeReconciler watches derived GVKs, classifies terminal conditions (Ready=True/False with reason-based drift/superseded/failed), appends OutcomeEntry idempotently.
8 unit tests: `test/unit/principal_propagation_test.go` (4), `test/unit/outcome_registry_test.go` (4).
Commit: `session/12: LineageController propagates declaringPrincipal, appends actorRef and createdAt, outcomeRegistry watcher`

**WS9 -- SetDescendantLabels callers (CLOSED):**
`platform/internal/controller/taloscluster_helpers.go`: 5 calls updated to pass `tc.GetAnnotations()[lineage.AnnotationDeclaringPrincipal]` as actorRef.
`wrapper/internal/controller/packexecution_reconciler.go`: 1 call updated with `pe.GetAnnotations()[lineage.AnnotationDeclaringPrincipal]`.
All tests pass on both repos.
Commits: `session/12: update SetDescendantLabels callers to pass actorRef` (platform and wrapper).

**WS10 -- guardian audit lineageIndexRef (CLOSED):**
`internal/database/cnpg.go`: LineageIndexRef struct and AuditEvent.LineageIndexRef field added.
`internal/controller/audit_helpers.go`: lineageRef() helper builds LineageIndexRef from kind/name/namespace.
`internal/controller/rbacpolicy_controller.go`: 2 audit events carry lineageIndexRef.
`internal/controller/rbacprofile_controller.go`: 4 audit events carry lineageIndexRef.
4 unit tests in `test/unit/controller/audit_lineage_test.go`.
Commit: `session/12: guardian audit records carry lineageIndexRef for governed object events`

**WS11 -- Full suite pass (CLOSED):**
All 4 repos green: go build, make test-unit, go vet.
- seam-core: ok
- platform: ok
- wrapper: ok
- guardian: ok

**WS12:** PROGRESS.md updated (this entry).

**WS13:** STOP. Awaiting Governor push authorization.

---

### session/13-live-cluster-validation (ontai root, conductor -- in progress)

**Role:** Lab Operator.

**WS1 -- session/12 merge (CLOSED):**
All session/12 PRs merged to main. ontai-schema PR #1, seam-core PR #9, guardian PR #7, platform PR #8, wrapper PR #7 -- all squash-merged, branches deleted.

**WS2 -- Image rebuild and enable bundle regeneration (CLOSED):**
All five operator images rebuilt and pushed to 10.20.0.1:5000 with tag `dev`.
Enable bundle (40 files) regenerated under `lab/configs/ccs-mgmt/compiled/enable/`.
Conductor go.mod bumped to seam-core session/12 merge commit.
Conductor PR raised on session/13 branch (pending Governor push).

**WS3-WS9 -- Phase scripts authored (CLOSED):**
All six phase scripts created and syntax-verified:
- `phase-a-mgmt-import.sh`: ccs-mgmt import, AC-1/AC-3
- `phase-b-dev-import.sh`: ccs-dev import, AC-2/AC-4
- `phase-c-dev-native-bootstrap.sh`: destructive ONT-native bootstrap (CONFIRM_DESTRUCTIVE gate)
- `phase-d-dev-capi-bootstrap.sh`: destructive CAPI bootstrap (CONFIRM_DESTRUCTIVE gate)
- `phase-e-helm-clusterpack.sh`: cert-manager ClusterPack deploy
- `phase-f-day2-ops.sh`: six day-2 scenarios (lineage, audit, RBAC intake, tenant GC)
- `run-all-phases.sh`: master runner for A+B

**WS10 -- Phase A execution (CLOSED):**
Three bugs found and fixed during live phase A run:

BLOCKER-001: SeamMembership CRD absent from enable bundle (SC-INV-003 violation).
Fix: Added `00-infrastructure-dependencies/seam-core-crds.yaml` with both ILI and SeamMembership CRDs.

BLOCKER-002: Guardian webhook timeout on cluster startup.
Fix: phase-a script now waits for guardian rollout status before applying phase 01 RBAC resources.

BLOCKER-003: Conductor --cluster-ref=ccs-mgmt arg missing from compiled enable bundle.
Fix: `04-conductor/conductor-deployment.yaml` updated with `args: [agent, --cluster-ref=ccs-mgmt]`.

BLOCKER-004: talosconfig Secret not in enable bundle -- TalosCluster reconciler blocked on KubeconfigUnavailable.
Fix: phase-a now creates `seam-mc-ccs-mgmt-talosconfig` secret from `lab/configs/ccs-mgmt/talosconfig` before applying TalosCluster CR.

Final result: TalosCluster ccs-mgmt Ready=True, AC-1 PASS (1/20 live), AC-3 PASS (0/22 live, stubs).

**WS11 -- Commit (CLOSED):**
All phase scripts and enable bundle fixes committed to session/13 branch.
Commit: a4412b8

**WS12:** PROGRESS.md and BACKLOG.md updated (this entry).

---

### session/11-pre-cluster-backlog-clearance (platform, guardian -- in progress, not pushed)

**Role:** Controller Engineer.

**WS1:** All 5 repos (platform, conductor, guardian, seam-core, wrapper) branched to
session/11-pre-cluster-backlog-clearance from clean main.

**WS2 -- PLATFORM-BL-CAPI-DERIVED-LINEAGE (CLOSED):**
SetDescendantLabels wired on all 4 CAPI-derived objects in taloscluster_helpers.go:
- `ensureSeamInfrastructureCluster`: SeamInfrastructureCluster gets ClusterProvision labels.
- `ensureCAPICluster`: CAPI Cluster gets ClusterProvision labels.
- `ensureTalosControlPlane`: TalosControlPlane gets ClusterProvision labels.
- `ensureWorkerPool` (MachineDeployment): per-pool MachineDeployment gets ClusterProvision labels.
All 4 pass `tc.Namespace` as `iliNamespace` so the DescendantReconciler can resolve the
ILI cross-namespace (TalosCluster is in seam-system, CAPI objects are in seam-tenant-{name}).
4 unit tests in `test/unit/controller/capi_lineage_test.go`.

**WS3 -- PLATFORM-BL-TENANT-GC (CLOSED):**
Finalizer `platform.ontai.dev/tenant-namespace-cleanup` added to CAPI-enabled TalosCluster.
`ensureTenantNamespaceCleanupFinalizer` wired at Step 0 of `reconcileCAPIPath`.
`handleTalosClusterDeletion` extended to delete `seam-tenant-{name}` namespace and remove the
finalizer. Cross-namespace ownerReferences are not supported by Kubernetes GC; a finalizer is
the correct mechanism. 4 unit tests in `test/unit/controller/taloscluster_gc_test.go`.

platform commit: f7a310c

**WS4 -- GUARDIAN-BL-RBAC-INTAKE (CLOSED):**
`RBACIntakeHandler` implemented in `internal/webhook/rbac_intake_handler.go`.
POST `/rbac-intake` endpoint registered via `AdmissionWebhookServer.RegisterRBACIntake`.
Handler stamps `ontai.dev/rbac-owner=guardian` on each submitted RBAC resource and applies
via SSA (`client.Apply`, field manager `guardian-rbac-intake`). Idempotent on Helm re-apply.
5 unit tests in `test/unit/webhook/rbac_intake_test.go`: annotation stamping, wrapped count,
empty list, invalid JSON, method guard.

guardian commit: c0c41fb

**WS5 -- CapabilityRBACProvision (no action):**
`rbac-provision` capability already fully implemented in `internal/capability/guardian.go`
from prior sessions. Unit tests exist in `test/unit/capability/guardian_test.go`. No gaps.

**WS6 -- Seven day2 conductor capabilities (no action):**
All 7 capabilities already fully implemented:
- etcd-backup, etcd-defrag, etcd-restore: `platform_etcd.go`.
- node-patch, node-scale-up, node-decommission, node-reboot: `platform_node.go`.
- pki-rotate, credential-rotate, hardening-apply, cluster-reset: `platform_cluster.go`.
Full unit tests exist. No stubs remain.

**WS7 -- Full suite pass:**
All 5 repos green: platform, guardian, seam-core, wrapper, conductor.

**WS8:** BACKLOG and PROGRESS updated (this entry).

**WS9:** Governor merge session completed. PRs squash-merged. All branches deleted. All repos on clean main.

---

### session/10c (platform, MERGED -- PR #9 merged to main 2026-04-20)

**Architecture correction:** 6 operational reconcilers (EtcdMaintenance, NodeMaintenance,
PKIRotation, ClusterReset, UpgradePolicy, NodeOperation) rewrote from incorrect per-operation
RunnerConfig creation to the correct Job-based pattern. Conductor's CapabilityPublisher
self-declares capabilities in RunnerConfig `status.capabilities` (CR-INV-005); operators
read this field before submitting any batch/v1 Job. WS8 (adding capabilities to bootstrap
RunnerConfig spec.steps) was dropped after architectural confirmation.

**WS6 -- Reconciler rewrite (6 files):**
- `platform/internal/controller/operational_job_base.go`: added
  `capabilityUnavailableRetryInterval`, `getClusterRunnerConfig`, `hasCapability`.
- `platform/api/v1alpha1/capability_conditions.go`: new file with
  `ConditionTypeCapabilityUnavailable`, `ReasonRunnerConfigNotFound`, `ReasonCapabilityNotPublished`.
- `platform/internal/controller/runnerconfig_cr.go`: added `CapabilityEntry` struct and
  `Capabilities []CapabilityEntry` to `OperationalRunnerConfigStatus`.
- 6 reconcilers rewritten: EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset,
  UpgradePolicy, NodeOperation. All now gate on cluster RunnerConfig capability, submit
  batch/v1 Job, watch OperationResult ConfigMap. NodeMaintenance: removed 4-step
  cordon/drain/operate/uncordon; single capability Job. UpgradePolicy: stack-upgrade is
  single compound capability.

**WS7 -- Unit test rewrite (2 files):**
- `platform/test/unit/controller/day2_reconcilers_test.go`: complete rewrite. All ORC
  checks replaced with Job checks. Added cluster RC pre-load pattern using `clusterRC()`
  helper. Added `successResultCM`, `failedResultCM`, `preExistingJob` helpers. NodeAffinity
  assertions replace ORC field assertions for node exclusion tests.
- `platform/test/unit/controller/runnerconfig_production_test.go`: rewritten for Job
  pattern. ORC list assertions replaced with Job list assertions.
- All unit tests pass (go test ./test/unit/... green).

WS8: CANCELLED. Conductor self-declares capabilities via CapabilityPublisher (CR-INV-005).
No changes needed to ensureBootstrapRunnerConfig.

WS9: PROGRESS.md updated (this entry).
WS10: Full suite pass -- go build, go vet, go test all green.
WS11: STOP. Waiting for Governor push authorization.

**session/10c continuation (Controller Engineer role, 2026-04-20):**

WS1: Pushed session/10c-runnerconfig-correction, PR #9 raised.

WS2 -- CAPI path audit (read-only, 6 checks):
1. TalosClusterReconciler CAPI path (reconcileCAPIPath) -- IMPLEMENTED (10-step).
2. SeamInfrastructureCluster created in seam-tenant namespace -- IMPLEMENTED.
3. CAPI Cluster created with correct infrastructureRef/controlPlaneRef -- IMPLEMENTED.
4. TalosControlPlane with replicas/version -- IMPLEMENTED.
5. CiliumPending condition when CAPI cluster reaches Running -- IMPLEMENTED.
6. Unit tests for CAPI path -- PARTIALLY IMPLEMENTED (machine reachability + Conductor tests existed; provisioning object creation tests absent).

WS3: Gap: no unit tests for SeamInfrastructureCluster, CAPI Cluster, TalosControlPlane,
MachineDeployment creation, or CiliumPending transition.

WS4 -- CAPI path unit tests (new file taloscluster_capi_provisioning_test.go):
5 tests added: SeamInfrastructureCluster creation, CAPI Cluster infrastructureRef,
TalosControlPlane replicas/version, CiliumPending condition on Running, MachineDeployment
per worker pool. All pass.

WS5 -- CI diagnosis and fixes (3 rounds):
- Round 1: lint FAIL -- 3 unused RunnerConfig helper functions removed from operational_job_base.go.
- Round 2: integration test FAIL -- etcdmaintenance_test.go rewrote from ORC to Job assertions,
  added cluster RunnerConfig setup via buildClusterRC helper.
- Round 3: integration test FAIL -- CapabilityEntry missing required Version field per CRD schema.
  Added Version string to CapabilityEntry struct, updated all test helpers. CI GREEN.

WS6: PR #9 merged to main. Commit 4fbc2068.

WS7: PROGRESS.md and BACKLOG.md updated.

Artefacts delivered:
- platform main: 6 reconcilers on Job-based pattern, CapabilityEntry struct with Version field,
  CAPI provisioning unit tests (5), integration tests updated, lint clean, all suites green.

---

### session/10d-tenant-onboarding-blockers (platform, seam-core, wrapper -- commits ready, not pushed)

**Role:** Controller Engineer.

**WS1:** session/10, session/10b PRs already merged to main -- confirmed via git log. No action needed.

**WS2:** All four repos (platform, seam-core, wrapper, guardian) branched to
session/10d-tenant-onboarding-blockers. Baseline unit tests green.

**WS3 -- SeamInfrastructureMachineReconciler audit (platform-design.md §3.1 six-step spec):**
All 6 steps confirmed COMPLETE:
1. Read CAPI Machine (via OwnerReference lookup) -- COMPLETE
2. Read bootstrap Secret (dataSecretName from Machine.Status.Bootstrap) -- COMPLETE
3. Apply via Talos maintenance API port 50000 -- COMPLETE (injectable MachineConfigApplier interface)
4. Poll IsOutOfMaintenance -- COMPLETE (MachineConfigApplied condition gates this)
5. Set providerID talos://{clusterName}/{ip} -- COMPLETE
6. Set status.ready=true -- COMPLETE

**WS4 -- Gap audit (read-only before any code):**

| Check | Component | Result |
|-------|-----------|--------|
| BPF params in TalosConfigTemplate | platform | NOT CORRECT: bpf_jit_harden=1 (must be 0); kernel.unprivileged_bpf_disabled absent (must be 0) |
| SetDescendantLabels on bootstrap RunnerConfig | platform | NOT WIRED |
| SetDescendantLabels on PackInstance | wrapper | NOT WIRED |
| SetDescendantLabels on PermissionSnapshot | guardian | DEFERRED -- architectural question (no single root per snapshot) |
| HardeningProfileRef in TalosClusterSpec | platform | ABSENT -- TalosClusterSpec has no HardeningProfileRef field; Decision 11 requires schema PR first |
| Tenant namespace ordering | platform | seam-tenant namespace created by TalosClusterReconciler before CAPI objects -- CORRECT |
| IndexName function in seam-core pkg/lineage | seam-core | ABSENT -- private lineageIndexName not exported; operators cannot compute ILI names |
| PackInstance in DerivedObjectGVKs | seam-core | ABSENT -- DescendantReconciler only watches RunnerConfig |

**WS5 -- Gaps filled:**

platform `internal/controller/taloscluster_helpers.go`:
- BPF fix: `net.core.bpf_jit_harden` changed from "1" to "0"; `kernel.unprivileged_bpf_disabled: "0"` added.
- SetDescendantLabels wired on bootstrap RunnerConfig in `ensureBootstrapRunnerConfig`:
  `lineage.SetDescendantLabels(rc, lineage.IndexName("TalosCluster", tc.Name), "platform", lineage.ConductorAssignment)`

seam-core `pkg/lineage/descendant.go`:
- Added `IndexName(kind, name string) string` export (formula: `strings.ToLower(kind) + "-" + name`).

seam-core `internal/controller/descendant_reconciler.go`:
- Added PackInstance GVK (`{Group: "infra.ontai.dev", Version: "v1alpha1", Kind: "PackInstance"}`) to DerivedObjectGVKs.

wrapper `internal/controller/packexecution_reconciler.go`:
- SetDescendantLabels wired before PackInstance Create:
  `lineage.SetDescendantLabels(pi, lineage.IndexName("PackExecution", pe.Name), "wrapper", lineage.PackExecution)`

Deferred (require Governor decision):
- HardeningProfile merge: TalosClusterSpec has no HardeningProfileRef. Decision 11 requires schema PR before implementation. New BACKLOG: PLATFORM-BL-HARDENINGPROFILE-MERGE.
- Guardian PermissionSnapshot wiring: EPGController upserts one snapshot per cluster over all RBACProfiles/policies; no single root RBACPolicy per snapshot. New BACKLOG: GUARDIAN-BL-PERMISSIONSNAPSHOT-WIRING.
- ILI cross-namespace lookup: Platform RC is in ont-system, TalosCluster ILI is in seam-system. DescendantReconciler uses obj.GetNamespace() for lookup; labels are set but reconciler cannot immediately resolve cross-ns ILI. New BACKLOG: PLATFORM-BL-ILI-CROSS-NS.

**WS6 -- Unit tests:**

platform `test/unit/controller/seaminfrastructuremachine_reconciler_test.go`:
5 new tests added:
1. TestSIMReconcile_BootstrapDataSecretNameAbsent
2. TestSIMReconcile_ApplyCalledWithCorrectAddressPortConfig (captureApplier helper)
3. TestSIMReconcile_MachineConfigApplied_SkipsApply
4. TestSIMReconcile_ReadyAfterOutOfMaintenance
5. TestSIMReconcile_IsOutOfMaintenanceError

captureApplier struct added to capture Talos API call args without network.

**WS4 C/D audit (session/10d continuation):**
- C: CiliumPending set when CAPI Cluster Running -- COMPLETE (taloscluster_controller.go Step 8)
- D: CiliumPending cleared when Cilium PackInstance Ready -- COMPLETE (Step 10/transitionToReady)

**WS6 audit:** Tenant namespace created at Step 1 of reconcileCAPIPath, before all CAPI objects (SIC, Cluster, TCT, TCP, MachineDeployments) -- YES.

**WS7 -- Compiler ccs-dev dry-run:**
Fixture from Governor brief had two gaps: (1) `importExistingCluster: true` without `machineConfigPaths` requires live cluster API -- not suitable for workstation dry-run; (2) `role: tenant` absent from fixture.
Fixed by: adding `role: tenant` and `machineConfigPaths` pointing to a locally generated init-node machine config. Also rebuilt compiler to pick up *CAPIConfig pointer change.
Output verified with fixed fixture + rebuilt compiler:
- spec.mode=import -- PASS
- spec.role=tenant -- PASS
- namespace=seam-tenant-ccs-dev -- PASS
- spec.capi block absent (nil pointer, omitempty suppressed) -- PASS (satisfies capi.enabled=false AND controlPlane absent)

**WS8 (session/10d continuation) -- Full suite pass (all 5 repos):**
- platform: go build CLEAN, go vet CLEAN, make test-unit PASS
- seam-core: go build CLEAN, go vet CLEAN, make test-unit PASS
- wrapper: go build CLEAN, go vet CLEAN, make test-unit PASS
- guardian: make test-unit PASS (no changes)
- conductor: make test-unit PASS (no changes)

**WS9 (session/10d continuation) -- TalosConfigTemplate CNI/CiliumPending tests:**
3 new tests added to taloscluster_capi_provisioning_test.go:
1. TestTalosClusterReconcile_CAPI_TalosConfigTemplateHasCNINone
2. TestTalosClusterReconcile_CAPI_TalosConfigTemplateHasBPFSysctls
3. TestTalosClusterReconcile_CAPI_CiliumPendingClearedWhenPackInstanceReady
All PASS. platform commit b2b93db.

**PROGRESS/BACKLOG updated (this entry).**
**WS11:** STOP. Waiting for Governor push authorization.

Commits ready (not pushed):
- platform: d57429e, b2b93db (BPF fix, SetDescendantLabels, SIM tests, CNI/BPF tests, CiliumPending-clear test)
- seam-core: 51bbce3 (IndexName export, PackInstance GVK)
- wrapper: 6c6afee (PackInstance SetDescendantLabels wiring)

---

### session/10-platform-operational-reconcilers (platform, conductor, seam-core, PRs open)

**Outcomes summary:**
- platform: 7 operational reconcilers implemented (EtcdMaintenance, NodeMaintenance,
  PKIRotation, ClusterReset, ClusterMaintenance, UpgradePolicy, NodeOperation)
  plus HardeningProfile validation. 32 e2e stubs, unit + integration tests.
- conductor: CapabilityEtcdDefrag naming fix (was etcd-maintenance), 14 stub handlers
  for all named operational capabilities registered in RunnerConfig.
- session/10b audit: 4 of 5 checks IMPLEMENTED, seam-core descendantRegistry ABSENT
  then filled in same session.
- seam-core: DescendantReconciler + SetDescendantLabels helper. Watches
  runner.ontai.dev/RunnerConfig, appends DescendantEntry to ILI on root-ili label.
- CNPG ordering decision: ILIs remain Kubernetes CRDs; no CNPG connector in seam-core.
  Guardian-db is the sole CNPG sink. seam-core has no dependency on CNPG.
- Operator wiring gap logged as SEAM-CORE-BL-DESCENDANT-LABELS (medium priority).

### session/10-platform-operational-reconcilers detail

WS1-WS2: Branched platform and conductor to session/10. WS2 audit confirmed all 7 day-2
reconcilers PRESENT AND COMPLETE. No reconciler implementation needed from scratch.

Critical gap found: conductor CapabilityEtcdMaintenance = "etcd-maintenance" mismatched
conductor-schema.md §6 ("etcd-defrag") and platform reconciler (capabilityEtcdDefrag).

**WS11 (conductor) -- CapabilityEtcdDefrag naming fix:**
Renamed CapabilityEtcdMaintenance to CapabilityEtcdDefrag in constants.go.
Updated stubs.go registration, platform_etcd.go handler references, and 3 test files.
Conductor unit tests green. Commit 4e52c9c.

**WS3 -- EtcdMaintenance:**
Added PVCFallbackEnabled bool field to EtcdMaintenanceSpec. Updated reconciler to set
EtcdBackupLocalFallback condition when PVCFallbackEnabled=true and no S3 configured.
Added 3 unit tests: restore RunnerConfig, PVC fallback, idempotent after Ready=True.
Created test/integration/day2/ suite and etcdmaintenance_test.go (2 envtest tests).
Created test/e2e/day2/ suite and etcdmaintenance_e2e_test.go (6 stubs). Updated Makefile.
Platform commit cd38ebd.

**WS4-WS10 -- Remaining reconciler unit tests and HardeningProfile Valid condition:**
- NodeMaintenance: 3 new tests (hardening-apply step, credential-rotate step, idempotent).
- PKIRotation: 3 new tests (in-progress, complete, failed).
- ClusterReset: 2 new tests (RunnerConfig complete, RunnerConfig failed).
- ClusterMaintenance: 1 new test (blockOutsideWindows=true sets ConductorJobGateBlocked).
- UpgradePolicy: 3 new tests (kube-upgrade RunnerConfig, CAPI path CAPIDelegated, failed).
- NodeOperation: 2 new tests (reboot RunnerConfig, failed).
- HardeningProfile: added ConditionTypeHardeningProfileValid/ReasonHardeningProfileValid/
  ReasonHardeningProfileInvalid constants to API types. Added validateHardeningProfileSpec()
  to reconciler. 3 new tests (valid, empty-patch invalid, empty-spec valid).
All 21 new unit tests pass. Platform commit 7f5da7d.

**WS12 -- AC-DAY2 e2e stubs:**
Created 6 per-reconciler e2e stub files in test/e2e/day2/ (NodeMaintenance, PKIRotation,
ClusterReset, UpgradePolicy, NodeOperation, ClusterMaintenance) plus day2_contracts_test.go
in test/e2e/. All stubs skip until TENANT-CLUSTER-E2E closed. AC-DAY2 contract documented.

**Test count summary (session/10 through session/10b):**
- Unit tests added: 21 (platform); 0 net change (conductor refactors only); 3 (seam-core)
- Integration test files: 1 new suite + 1 test file (2 tests, skip without KUBEBUILDER_ASSETS)
- e2e stubs added: 7 new files, 32 stubs total (all skip until TENANT-CLUSTER-E2E)

**session/10b WS2 audit (read-only):**
All 5 checks verified across platform, wrapper, conductor, guardian, seam-core:

| Check | Component | Result |
|-------|-----------|--------|
| 1 | Wrapper PackInstance drift + SecurityViolation | IMPLEMENTED |
| 2 | Conductor local PermissionService (gRPC) | IMPLEMENTED |
| 3 | seam-core descendantRegistry append | ABSENT -- filled in WS3 |
| 4 | Guardian PermissionService gRPC server | IMPLEMENTED |
| 5 | Conductor PackReceipt creation on tenant cluster | IMPLEMENTED |

**session/10b WS3 -- seam-core DescendantReconciler (fills check 3 gap):**
Added DescendantReconciler in internal/controller/descendant_reconciler.go. Watches
DerivedObjectGVKs (starting with runner.ontai.dev/RunnerConfig). When a derived object
carries label infrastructure.ontai.dev/root-ili, appends a DescendantEntry to the named
ILI's DescendantRegistry. Idempotent: UID guard prevents duplicates. Registered in main.go
alongside LineageReconciler loop.
Added SetDescendantLabels helper in pkg/lineage/descendant.go for operators to set the
three required labels (root-ili, seam-operator, creation-rationale) at derived object
creation time.
3 unit tests (append entry, idempotent, no-op without label). seam-core commit 8312ad7.

WS4 cross-repo field reference verified during WS2: wrapper gate 3 reads Fresh condition
type from PermissionSnapshot as unstructured -- matches guardian API. No mismatch.

**WS5 full suite pass:**
All five repos (platform, conductor, wrapper, guardian, seam-core): make test-unit green.
No regressions.

---

### session/9b-corrections (ontai root, merged to main)

session/9b: .gitignore correction. app-core and ontai-schema are independent repos
with ontai-dev remotes and must not appear in ontai root .gitignore. Entries removed.
.claude/, ONT-Seam-Architecture.pptx, and build_pptx.py remain correctly gitignored
as local working files.

---

### session/1-governor-init (all repos, merged to main)

Foundation work across all six operators. Established all CRD types, reconcilers,
shared library, admission webhook, bootstrap window, lineage system, CAPI integration,
and Wrapper pack delivery. Platform onboards management cluster via import path.
Guardian CNPG audit sink operational. EPG auto-refresh live. ClusterPack delivery
end-to-end verified. Key invariants closed: INV-020 (bootstrap window), CS-INV-001,
SC-INV-002 (condition vocabulary). enable-ccs-mgmt.sh CI script committed. Commits
across all six repos -- see GIT_TRACKING.md for full log.

### session/2-lineage-sync (seam-core, guardian)

Closed SEAM-CORE-BL-LINEAGE. Root cause: PermissionSnapshot was not a root GVK but
received LineageSynced=False initialization. Fixed by removing erroneous init block
from permissionsnapshot_controller.go. PackInstance test gap closed with new regression
guard. seam-core commit 52de8d3. guardian commit c36ffd3.

### session/3-reconciler-bugs (platform)

Pre-existing guardian envtest FAIL recorded as GUARDIAN-BL-ENVTEST-FAIL (not introduced
by session/3). RetryOnConflict added to TalosClusterReconciler status patch. LocalQueue
creation in seam-tenant for tenant clusters added to platform. CI-SCRIPT backlog item
closed (enable-ccs-mgmt.sh committed).

### session/4-webhook-hardening-and-compiler-fixes (guardian, conductor, platform, ontai root)

PRs open as of 2026-04-20. Four backlog items closed:

**G-BL-CR-IMMUTABILITY (guardian PR #5):**
Operator-authorship guard blocking human UPDATE/PATCH on PackInstance, RunnerConfig,
PermissionSnapshot, PackExecution. Pure decision function EvaluateOperatorAuthorship.
Bootstrap window bypass. 10 unit tests, 6 e2e stubs. Commit 16c85f4.

**C-COREDNS-PATCH (conductor PR #3):**
Removed INV-001-violating writeCoreDNSDSNSPatchScript from compiler. Phase 05 meta
updated to reference CI step 7a inline patch. 2 unit tests, 3 e2e stubs. Commit a2eada4.

**C-KUEUE-WEBHOOK (conductor PR #3):**
Moved Kueue webhook scoping from Step 7d to Phase 00 in enable-ccs-mgmt.sh immediately
after kueue-controller.yaml apply. wait_crd guard added. 1 unit test, 3 e2e stubs.
Commit a0a4c53.

**C-34 (platform PR #4, conductor PR #3):**
TalosClusterSpec.CAPI changed from CAPIConfig to *CAPIConfig. nil pointer suppresses
capi block in YAML when disabled (management cluster path). CAPIEnabled() helper added.
deepcopy, 5 controllers, 3 test files updated in platform (commit 7f70533). Conductor
management cluster builders updated, regression test added (commit f7c66ad).

Two Governor directives codified in CLAUDE.md:
- Section 16: Context Compaction Safety Protocol
- Section 17: e2e CI Contract and Skip-Reason Standard

### session/7-ci-pipelines (all repos, in progress)

CI infrastructure only. No operator reconciler changes.

**WS1:** All 6 repos branched to session/7-ci-pipelines.

**WS2 -- Makefile targets (all 5 operator repos):**
Added test-unit, test-integration, test-all targets uniformly. Existing targets unchanged.
platform and seam-core test-integration exits 0 (no integration tests). conductor, guardian,
wrapper test-integration runs envtest suite via KUBEBUILDER_ASSETS.

**RunnerConfig json tag fix (conductor):**
RunnerConfigSpec and nested types (RunnerConfigStep, PhaseConfig, OperationalHistoryEntry,
RunnerConfigStepResult, ConfigMapRef, SecretRef, RunnerConfigStatus) had no json tags.
Go marshaled with UpperCase keys; CRD schema expects camelCase. All 4 conductor integration
tests were failing with Required value (clusterRef, runnerImage). Fixed by adding json tags
to all struct fields. All 4 tests now pass.

**GUARDIAN-BL-ENVTEST-FAIL resolved:**
Three root causes found and fixed:

1. RBACPolicyReconciler finalizer + GenerationChangedPredicate: the finalizer addition returns
   early and the subsequent metadata-only Update does not trigger another reconcile (generation
   unchanged). Fix: do not return early after adding finalizer; continue reconcile in same pass.
   guardian/internal/controller/rbacpolicy_controller.go.

2. EPGReconciler OperatorNamespace not set in test setup (epg_reconciler_test.go):
   SSA patch targeted namespace "" which does not exist. Fix: set OperatorNamespace=testNamespace
   in both epg and controller suite TestMain.

3. IdentityProviderReconciler OIDC reachability check races 10s timeout against 10s test poll:
   Fix: inject failFastHTTPClient in controller suite TestMain. OIDC check fails immediately
   allowing status patch before test timeout.

All guardian integration suites now pass: controller (27 tests), epg (1 test), lineage (3 tests),
webhook (cached).

**WS3-WS5 -- GitHub Actions per-repo ci.yaml:**
conductor, guardian, platform, wrapper, seam-core each have .github/workflows/ci.yaml.
Steps: checkout, setup-go, build, lint (golangci-lint direct), test-unit, envtest install
(where applicable), test-integration, e2e (skip count to GITHUB_STEP_SUMMARY), upload artifacts
on failure.

**WS6 -- Cross-repo CI (.github/workflows/cross-repo-ci.yaml in ontai root):**
Triggers: workflow_dispatch and daily 02:00 UTC. Dependency order: seam-core -> guardian ->
platform+wrapper -> conductor. Summary job posts results table to GITHUB_STEP_SUMMARY and opens
GitHub issue on any failure.

**WS7:** All 6 YAML files validated with python3 yaml.safe_load.

**WS8:** Local smoke tests passed:
- conductor: build, test-unit, test-integration, e2e all exit 0.
- guardian: build, test-unit, test-integration (50s), e2e all exit 0.

**WS9:** PROGRESS.md, BACKLOG.md, GIT_TRACKING.md updated.

**WS10:** PRs raised: conductor #6, guardian #7, platform #6, wrapper #4, seam-core #5, ontai #2.

### session/9-pre-cluster-verify (ontai root, merged to main)

Pre-cluster verification pass before raising session/9 PRs.

**WS1:** conductor session/8-acceptance-contracts local branch deleted (remote squash-merged in session/8).

**WS2:** Five untracked files disposed in ontai root .gitignore:
- .claude/: Claude project context -- never committed
- ONT-Seam-Architecture.pptx + build_pptx.py: generated working documents -- gitignored
- app-core/: scaffold for future ontai-dev/app-core repo (APP-CORE backlog) -- gitignored
- ontai-schema/: schema.ontai.dev GitHub Pages site -- gitignored

**WS3 -- AC-1 platform import path verified (4 checks):**
All four checks pass. No gap found, no implementation required.
- A: TalosClusterModeImport branch present at taloscluster_controller.go:227
- B: status.origin=imported set at line 228
- C: ensureBootstrapRunnerConfig called unconditionally before import branch (line 210); comment at line 221 confirms RunnerConfig ensured above for Conductor attachment
- D: import path returns ctrl.Result{}, nil at line 282 -- no Kueue Job

**WS4 -- AC-2 wrapper gate chain verified:**
PackExecutionReconciler implements all 5 gates in order: gate 0 ConductorReady, gate 1 Signature (ClusterPack.status.Signed=true), gate 2 Revocation, gate 3 PermissionSnapshot Fresh=true, gate 4 RBACProfile provisioned=true. Gate watches on PermissionSnapshot and RBACProfile present at packexecution_reconciler.go:792.

**WS5 -- AC-2 conductor signing loop verified:**
signing_loop.go implements SigningLoop: signs PackInstance and PermissionSnapshot with Ed25519, writes ontai.dev/pack-signature annotation that ClusterPackReconciler reads to set Status.Signed=true. INV-026 enforced.

**WS6 -- AC-3 guardian audit trail verified:**
- rbacprofile.provisioned emitted at rbacprofile_controller.go:336
- rbac.would_deny emitted at rbac_handler.go:73 (webhook)
- LazyAuditWriter in database/lazy.go; CNPG sink in database/cnpg.go

**WS7 -- Full suite pass:**
All four repos (platform, wrapper, conductor, guardian): go build, go vet, make test-unit all exit 0. No regressions.

---

### session/8-acceptance-contracts (platform, wrapper, guardian, seam-core, in progress)

Acceptance contract tests (AC-1 through AC-5) and run-acceptance.sh runner.

**AC-1 -- Management cluster import (platform):**
Five unit tests in platform/test/unit/controller/taloscluster_import_test.go covering:
origin=imported, Ready=True, exactly one RunnerConfig in ont-system, no Job submitted,
second reconcile idempotent, LineageSynced=False/LineageControllerAbsent on first pass.
Five e2e stubs in platform/test/e2e/ac1_mgmt_import_test.go skip until MGMT_KUBECONFIG.
platform commit d4e7f26.

**AC-2 -- ClusterPack deploy gate chain (wrapper + guardian):**
Wrapper: five unit tests (packexecution_gates_test.go): gate 1 unsigned, gate 2 revoked,
gate 3 stale snapshot, gate 4 RBAC unprovisioned, all-gates-pass Job submission. Seven e2e
stubs (ac2_clusterpack_deploy_test.go) skip until TENANT-CLUSTER-E2E closed.
Guardian: five unit tests (epg_stale_predicate_test.go): permissionSnapshotStaleFilter
passes Fresh->Stale, suppresses all other transitions, suppresses Create/Delete/Generic.
wrapper commits ebb327d; guardian commit a89242e.

**AC-3 -- Guardian audit sweep (guardian):**
Four unit tests (audit_sweep_test.go): LazyAuditWriter drops when ErrDatabaseNotReady,
forwards after Set, BootstrapAnnotationRunnable emits bootstrap.annotation_sweep_complete,
RBACPolicyReconciler emits rbacpolicy.validated. Five e2e stubs skip until
GUARDIAN-BL-ENVTEST-FAIL closed. guardian commit c78f474.

**AC-4 -- LineageController manifest tracking (seam-core):**
Five unit tests (ac4_lineage_controller_test.go): ILI with deterministic name, LineageSynced
transitions to True/LineageIndexCreated, governance annotation on root, idempotency, all 9
GVKs registered. Seven e2e stubs skip until TENANT-CLUSTER-E2E closed. seam-core commit e4d2cfa.

**AC-5 -- DSNS lineage tracking in seam.ontave.dev (seam-core):**
Six unit tests (ac5_dsns_test.go): TalosCluster cluster-topology, PackInstance pack-lineage,
IdentityBinding identity-plane, RunnerConfig execution-authority, zone always has SOA+NS,
all 5 DSNSGVKs registered. Seven e2e stubs skip until TENANT-CLUSTER-E2E closed.
seam-core commit 96724b8.

**WS7 -- run-acceptance.sh:**
lab/scripts/run-acceptance.sh created. Runs make test-unit for all 5 repos sequentially.
All 5 pass: 5 passed, 0 failed. (lab/ is gitignored -- file is local only.)

**WS8 -- Full suite pass:**
All five repo unit suites green via run-acceptance.sh. No regressions.

---

## Open Backlog (High Priority)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. |
| PLATFORM-BL-TENANT-GC | platform | TalosCluster deletion should cascade to seam-tenant namespace. |
| G-BL-CNPG-POOLER-AUTH | guardian | Connect to rw service not pooler. md5 hash caching issue. |
| GUARDIAN-BL-ENVTEST-FAIL | guardian | CLOSED 2026-04-20 (session/7). Three root causes fixed: RBACPolicy finalizer early-return, EPGReconciler OperatorNamespace not set in test, OIDC HTTP timeout race. All suites green. |

---

## Next Session Candidates

1. TENANT-CLUSTER-E2E -- ccs-dev onboarding. Promotes all AC-2/AC-4/AC-5 e2e stubs to live.
2. G-BL-CNPG-POOLER-AUTH -- guardian CNPG connection fix.
3. PLATFORM-BL-TENANT-GC -- TalosCluster cascade deletion to seam-tenant namespace.
