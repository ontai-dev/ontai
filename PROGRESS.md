# ONT Platform Progress

**Last updated:** May 2, 2026 (session/18)

**Current state:** Full DriftSignal cycle working end-to-end on ccs-dev for ingress-nginx and cert-manager. Three bugs fixed this session. PE ownerRef gap closed with PE-watching EventSource on ClusterPackReconciler. Session/17 PRs still pending Governor merge.

**Full history:** PROGRESS-archive-2026-04-20.md

---

## Open Work

### Blocking Alpha

No blocking alpha items currently open. All previously tracked items have been resolved.

### Infrastructure (blocks e2e)

| ID | Description |
|----|-------------|
| ccs-dev unreachable (10.20.0.20) | Blocks TENANT-HP-CLUSTER, TENANT-PKI-CLUSTER-REACH, TENANT-HP-NODE |
| ccs-mgmt cp3 NotReady | Talos API down, causing conductor pod CrashLoopBackOff; blocks MGMT-HP-NODE |

---

## Session/17 Work (2026-05-02) -- PRs Pending Merge

### Branches with unmerged work

| Repo | Branch | Key changes |
|------|--------|-------------|
| conductor | session/17-etcd-s3-credential-injection | `bytes.NewReader` fix for MinIO S3 upload over HTTP |
| conductor | session/17-pki-rotation-automation | `Kubeconfig()` method + kubeconfig Secret refresh in `pkiRotateHandler` |
| conductor | session/17-hardening-profile-tests | per-node hardeningApply, TalosVersionDriftLoop (T-23), rolling upgrade, RunnerConfig-missing DriftSignal |
| platform | session/17-etcd-s3-credential-injection | S3 credential injection for etcd backup/restore |
| platform | session/17-pki-rotation-automation | PKI rotation automation + cert expiry detection |
| platform | session/17-hardening-profile-tests | DriftSignalReconciler InfrastructureTalosCluster handler, T-24 Decision H cascade, RBAC fixes |

### T-23 Talos Version Drift -- Live E2E (ccs-dev)

All 7 steps passed. ccs-dev nodes corrected from v1.9.5 back to v1.9.3 via rolling talos-upgrade Job. TCOR at revision 3.

### Known test issues requiring fix before merge

| Test file | Issue |
|-----------|-------|
| `hardeningprofile_e2e_test.go` | `mgmtWorkerNode = "ccs-mgmt-w2"` hardcoded; does not exist on ccs-mgmt; TargetNodes only governs Job scheduling exclusion, not capability scope |

---

## Session/18 Work (2026-05-02) -- Committed to main/branch

### Three Bugs Fixed

| Bug | File | Fix |
|-----|------|-----|
| DriftSignal escalation on terminating namespaces | `conductor/internal/agent/pack_receipt_drift_loop.go` | `namespaceTerminating()` guard skips drift increment when namespace has DeletionTimestamp |
| packDeployHandler alphabetical-first-match | `conductor/internal/capability/wrapper.go` | Uses `params.OperationResultCM` for direct `Get` instead of `List + break` |
| Wrapper RunnerConfig EventSource uses pre-Phase-2B GVK | `wrapper/internal/controller/packexecution_reconciler.go` | Updated to `infrastructure.ontai.dev/v1alpha1/InfrastructureRunnerConfig` |

### PE ownerRef gap closed

Added `MapPackExecutionToClusterPack` and PE delete-only watch to `ClusterPackReconciler.SetupWithManager`. When a PE is externally deleted (e.g. by `DriftSignalHandler`), the mapper deletes the PackInstance (clearing the version guard) and triggers ClusterPack reconcile, which creates a fresh PE. Unit test: `TestClusterPackReconciler_PackExecutionDeletedRecreatesPE`.

### Commits

| Repo | Branch | Hash | Message |
|------|--------|------|---------|
| conductor | session/17-hardening-profile-tests | cd63b00 | fix three drift/pack-deploy alphabetical-first-match bugs |
| wrapper | main | ee36691 | fix stale runner.ontai.dev RunnerConfig watch GVK |
| wrapper | main | d586993 | PE-watching EventSource on ClusterPackReconciler to retrigger delivery on external PE deletion |

### Live E2E (ccs-dev) -- DriftSignal cycle validated

| # | Step | Result |
|---|------|--------|
| 1 | ingress-nginx Deployment deleted | PASS |
| 2 | DriftSignal emitted | PASS |
| 3 | PE deleted by handler, new PE created | PASS |
| 4 | pack-deploy Job deploys nginx (not cert-manager) | PASS |
| 5 | drift-nginx-ccs-dev confirmed | PASS |
| 6 | cert-manager DriftSignal confirmed after redeploy | PASS |

---

## Next Session Candidates

1. Cluster recovery -- cp3 NotReady, ccs-dev unreachable; blocks all TENANT e2e and MGMT-HP-NODE.
2. Governor merge of session/17 PRs (conductor, platform branches).
3. MGMT-HP-NODE test fix -- `ccs-mgmt-w2` hardcoded node does not exist; decide whether single-node targeting should be implemented.
4. Phase 6 (T-20, T-21) -- day2 scheduling with node awareness; design session required.
