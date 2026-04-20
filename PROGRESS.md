# ONT Platform Progress

**Current state:** session/7-ci-pipelines in progress (all repos). session/4 PRs still open.
**Full history:** PROGRESS-archive-2026-04-20.md

---

## Branch Summary

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

1. WS10: Push session/7-ci-pipelines branches and raise PRs (conductor, guardian, platform, wrapper, seam-core, ontai root).
2. Merge session/4 PRs (guardian #5, conductor #3, platform #4, ontai #1).
3. ontai-schema PR for any fields added by session/4 (Schema-First contract).
4. TENANT-CLUSTER-E2E -- ccs-dev onboarding.
