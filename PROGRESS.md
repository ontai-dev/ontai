# ONT Platform Progress

**Current state:** session/10-platform-operational-reconcilers in progress (WS7 next: STOP before push/PR). session/9b-corrections merged. session/9 complete. session/8 merged.
**Full history:** PROGRESS-archive-2026-04-20.md

---

## Branch Summary

### session/10-platform-operational-reconcilers (platform, conductor, seam-core, in progress)

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
