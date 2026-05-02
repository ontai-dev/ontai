# ONT Platform Progress

**Last updated:** May 2, 2026 (session/18 close)

**Current state:** All session/17 and session/18 PRs squash-merged to main. K8s version drift detection (KubernetesVersionDriftLoop) live on ccs-dev. DriftSignal drift-k8s-version-ccs-dev emitted, reconciler created corrective UpgradePolicy. Signal in queued state; will confirm once nodes revert to 1.32.3. Five PRs merged: seam-core #16, conductor #29+#30, platform #19+#20.

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

## Session/17+18 Work (2026-05-02) -- MERGED

### PRs Merged (this session)

| PR | Repo | Branch | Summary |
|----|------|--------|---------|
| seam-core #16 | seam-core | session/17-pki-rotation-automation | PkiRotationThresholdDays + PkiExpiryDate fields; lint fix |
| conductor #29 | conductor | session/17-hardening-profile-tests | PKI rotation, TalosVersionDriftLoop, hardeningApply, K8s drift loop, lint fixes |
| conductor #30 | conductor | session/18-k8s-version-drift | KubernetesVersionDriftLoop implementation + unit tests |
| platform #19 | platform | session/17-hardening-profile-tests | DriftSignalReconciler InfrastructureTalosCluster handler, PKI automation |
| platform #20 | platform | session/18-k8s-version-drift | DriftSignalReconciler K8s version drift handler, ensureCorrectiveKubeUpgradePolicy |

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

### K8s Version Drift -- Live E2E (ccs-dev)

| # | Step | Result |
|---|------|--------|
| 1 | `talosctl upgrade-k8s` to v1.32.4 (out-of-band) | PASS |
| 2 | KubernetesVersionDriftLoop emitted drift-k8s-version-ccs-dev | PASS |
| 3 | DriftSignalReconciler created corrective UpgradePolicy drift-k8s-version-ccs-dev | PASS |
| 4 | Signal in queued state | PASS |
| 5 | Confirm (nodes revert to 1.32.3 via UpgradePolicy Job) | PENDING -- UpgradePolicy Job not yet run |

### Open Item

drift-k8s-version-ccs-dev signal queued; corrective UpgradePolicy `drift-k8s-version-ccs-dev` exists in seam-tenant-ccs-dev targeting kubernetesVersion=1.32.3. UpgradePolicyReconciler must submit kube-upgrade Job to revert nodes from 1.32.4 -> 1.32.3. Until then signal stays queued. If keeping 1.32.4 is intentional, update TalosCluster spec.kubernetesVersion to 1.32.4.

---

## Next Session Candidates

1. Cluster recovery -- cp3 NotReady, ccs-dev unreachable; blocks all TENANT e2e and MGMT-HP-NODE.
2. K8s drift revert -- run UpgradePolicyReconciler or manually confirm drift-k8s-version-ccs-dev.
3. MGMT-HP-NODE test fix -- `ccs-mgmt-w2` hardcoded node does not exist; decide whether single-node targeting should be implemented.
4. Phase 6 (T-20, T-21) -- day2 scheduling with node awareness; design session required.
