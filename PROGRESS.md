# ONT Platform Progress

**Current state:** session/5-envtest-capi-day2 complete. PRs pending: conductor, platform, seam-core. session/4 PRs still open.
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

---

## Open Backlog (High Priority)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. |
| PLATFORM-BL-TENANT-GC | platform | TalosCluster deletion should cascade to seam-tenant namespace. |
| G-BL-CNPG-POOLER-AUTH | guardian | Connect to rw service not pooler. md5 hash caching issue. |
| GUARDIAN-BL-ENVTEST-FAIL | guardian | Integration/webhook envtest fails pre-existing. Investigation needed. |

### session/5-envtest-capi-day2 (conductor, platform, seam-core)

PRs pending as of 2026-04-20. Six workstreams completed:

**WS2 -- Compiler output conformance tests (conductor):**
Three fixture files (mgmt-import, tenant-import, tenant-capi) and four table-driven tests
verifying TalosCluster YAML round-trip and CAPI block nil-suppression (C-34). Tests in
cmd/compiler/compile_bootstrap_variants_test.go. Commit includes CAPIInput struct extension
with ControlPlane, Workers, CiliumPackRef nested fields.

**WS3 -- CAPI lifecycle integration tests (platform):**
test/integration/capi/capi_lifecycle_test.go. Six tests covering CAPI provisioning path,
idempotency, SIM NoCAPIMachine, BootstrapDataNotReady, deletion finalizer, and Conductor
deployment stub. All CAPI objects as unstructured (no CAPI CRDs in go.mod).

**WS4 -- Management cluster day2 integration tests (platform):**
test/integration/day2/mgmt_day2_test.go. Nine tests: S3 hierarchy (4 scenarios),
NodeMaintenance 4-step credential-rotate, PKIRotation, ClusterReset gate (blocked + approved),
operator restart recovery. Uses fake client with defaultS3Secret and perOpS3Secret helpers.

**WS5 -- Tenant day2 integration tests (platform):**
test/integration/day2/tenant_day2_test.go. Three tests: ImportMode and CAPIMode backup
(both use direct RunnerConfig), S3 absent in tenant namespace.

**WS6 -- CAPI day2 integration tests (platform):**
test/integration/day2/capi_day2_test.go. Three tests: UpgradePolicy CAPI path (CAPI Cluster
pre-created in seam-tenant ns), ClusterMaintenance Paused condition (fixed clock), NodeOperation
non-CAPI path. Key fixes: UpgradeType required, reconcileCAPIPause no-op without CAPI Cluster.

**WS7 -- seam-core LineageController all-GVKs integration tests (seam-core):**
test/integration/lineage/all_gvks_test.go. Forty sub-tests (4 tests x 9 GVKs + count).
Covers ILI creation, RootBinding fields (Kind/Name/UID/ObservedGeneration), LineageSynced
transition, ILI naming format, and GVK count invariant. All pass.

**Conductor integration envtest:** Pre-existing failure unchanged (requires etcd binary).
All unit tests pass across conductor, platform, seam-core.

---

## Next Session Candidates

1. Merge session/4 PRs (guardian #5, conductor #3, platform #4, ontai #1).
2. Merge session/5 PRs (conductor, platform, seam-core).
3. ontai-schema PR for any fields added by sessions 4-5 (Schema-First contract).
4. GUARDIAN-BL-ENVTEST-FAIL investigation.
5. TENANT-CLUSTER-E2E -- ccs-dev onboarding.
