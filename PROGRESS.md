# ONT Platform Progress

**Current state:** session/6-integration-envtest-gaps complete (guardian, conductor). GUARDIAN-BL-ENVTEST-FAIL closed.
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

### session/6-integration-envtest-gaps (guardian, conductor)

Closed GUARDIAN-BL-ENVTEST-FAIL. Three root causes found and fixed:

**Root cause 1 -- RBACPolicyReconciler Requeue=true missing (rbacpolicy_controller.go):**
After adding the finalizer, the reconciler returned ctrl.Result{}, nil. GenerationChangedPredicate
filtered the subsequent metadata-only Update event (finalizer addition does not bump generation),
so the second reconcile that sets status conditions never ran. Fix: changed to ctrl.Result{Requeue: true}.

**Root cause 2 -- IdentityProviderReconciler HTTP timeout in envtest (rbacpolicy_controller_test.go TestMain):**
IdentityProviderReconciler registered without HTTPClient field, causing real OIDC HTTP calls
to https://accounts.example.com/.well-known/openid-configuration that block for oidcReachabilityTimeout
(10s). Deferred status patch only fires after HTTP returns; 10s poll expired first.
Fix: added alwaysReachableHTTPDoer test double injected in TestMain.

**Root cause 3 -- EPGReconciler OperatorNamespace empty in epg integration suite:**
EPGReconciler registered without OperatorNamespace, defaulting to "". All SSA patches targeted
namespace "", causing "server could not find the requested resource".
Fix: set OperatorNamespace: testNamespace in epg TestMain registration.

**Root cause 4 -- lineage integration probe PermissionSet missing required spec.permissions:**
waitForLineageWebhookActive created a probe PermissionSet without spec.permissions (a required
field per CRD validation). Webhook probe create panicked.
Fix: added a minimal PermissionRule to the probe object.

All four guardian integration suites now pass: controller (50s), epg (7s), lineage (6s), webhook (5s).

New conductor integration tests added:

**WS2 -- WAL integration tests (test/integration/federation/wal_integration_test.go):**
5 tests: WriteAndReplay, PartialAck, ErrWALFull callback, Compact, ConcurrentWrites.

**WS3 -- Federation stream tests (test/integration/federation/stream_integration_test.go):**
4 tests: HeartBeat ACK, AuditEventBatch ACK, ClusterID from cert SAN, WAL replay on reconnect.

**WS4 -- Signing loop tests (test/integration/signing/signing_integration_test.go):**
5 tests: SigningLoop signs + stores Secret, idempotent on stale signature, PackInstancePullLoop
valid signature creates PackReceipt, tampered signature PackReceipt verified=false,
SnapshotPullLoop invalid signature patches DegradedSecurityState.

CI gap recorded as CONDUCTOR-BL-INTEGRATION-CI: conductor and guardian Makefile test targets
do not include integration suites; requires dedicated test-integration target addition.

---

## Open Backlog (High Priority)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. |
| PLATFORM-BL-TENANT-GC | platform | TalosCluster deletion should cascade to seam-tenant namespace. |
| G-BL-CNPG-POOLER-AUTH | guardian | Connect to rw service not pooler. md5 hash caching issue. |

---

## Next Session Candidates

1. Merge session/4 PRs (guardian #5, conductor #3, platform #4, ontai #1).
2. ontai-schema PR for any fields added by session/4 (Schema-First contract).
3. TENANT-CLUSTER-E2E -- ccs-dev onboarding.
4. Add test-integration Makefile targets in conductor and guardian (CONDUCTOR-BL-INTEGRATION-CI).
