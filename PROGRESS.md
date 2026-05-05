# ONT Platform Progress

**Last updated:** May 5, 2026 (session/23 close)

**Current state:** Production graph pruned to production code only (2,755 nodes, 4,248 links, 266 communities). Test graph introduced at graphify-tests-out/ (2,247 nodes, 4,914 links, 165 communities). Envtest binaries installed locally; all integration test suites green across all 6 repos. make envtest-setup target added to root Makefile, pinned to K8s 1.32.x matching ccs-mgmt. Session/22 cleanup: 6 PRs merged (Decision G violation removed, ont-lab removed, hardeningApply VIP fix, PlatformTenant reference dropped, .graphifyignore created, NewRegistry comment added).

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

## Session/23 Work (2026-05-05) -- IN PROGRESS

### Task 1 -- Test-only graphify graph

| Item | Details |
|------|---------|
| graphify-tests.py | Builder script at ontai root; collects *_test.go + test/ dirs from all repos |
| graphify-tests-out/ | Added to .gitignore; 2,247 nodes, 4,914 links, 165 communities |
| CONTEXT.md | Updated with two-graph model: production graph and test graph sections |

### Task 2 -- Envtest local setup

| Item | Details |
|------|---------|
| setup-envtest | Already installed at /home/saigha01/go/bin/setup-envtest |
| make envtest-setup | New root Makefile target; installs K8s 1.32.x binaries to ~/.local/share/kubebuilder-envtest |
| make envtest-path | Companion target; prints KUBEBUILDER_ASSETS for shell eval |
| guardian integration | 4 suites: controller, epg, lineage, webhook -- all pass |
| conductor integration | 3 suites: main, federation, signing -- all pass |
| platform integration | 2 suites: capi, day2 -- all pass |
| wrapper integration | 1 suite -- passes |
| seam-core integration | 1 suite -- passes |
| suite_test.go comments | Updated in conductor, platform, wrapper to reference make envtest-setup |

### Session/23 PRs

| PR | Repo | Branch | Summary |
|----|------|--------|---------|
| ontai #21 (pending) | ontai | session/23-test-graph | graphify-tests.py, envtest-setup Makefile target, CONTEXT/PROGRESS/GIT_TRACKING updates |
| conductor #39 (pending) | conductor | session/23-envtest-setup | suite_test.go comment fix |
| platform #23 (pending) | platform | session/23-envtest-setup | suite_test.go comment fix |
| wrapper #18 (pending) | wrapper | session/23-envtest-setup | suite_test.go comment fix |

---

## Session/22 Work (2026-05-05) -- MERGED

### Cleanup (6 items)

| PR | Repo | Summary |
|----|------|---------|
| ontai #18 | wrapper (via ontai) | Delete wrapper TCOR CRD YAML -- Decision G violation |
| ontai #19 | ontai | Remove ont-lab/ directory and .gitignore entry |
| conductor #37 | conductor | hardeningApply VIP fix: ClusterEndpoint filter + waitForNodeStable + 3 tests |
| platform #22 | platform | Drop PlatformTenant forward-looking reference from CLAUDE.md Step 4b |
| ontai #20 | ontai | .graphifyignore + graph rebuild: 5268->2755 nodes, test/lab ghost nodes pruned |
| conductor #38 | conductor | NewRegistry dual-mode usage comment |

---

## Session/21 Work (2026-05-04) -- MERGED

### Governor Directive: graphify replaces CODEBASE.md

| PR | Repo | Summary |
|----|------|---------|
| ontai #17 | ontai | CLAUDE.md Graphify Protocol, CONTEXT.md graphify section, root CODEBASE.md removed, graphify-out/ committed |
| conductor #36 | conductor | Remove CODEBASE.md |
| guardian #20 | guardian | Remove CODEBASE.md |
| platform #21 | platform | Remove CODEBASE.md |
| seam-core #17 | seam-core | Remove CODEBASE.md |
| wrapper #17 | wrapper | Remove CODEBASE.md |
| domain-core #4 | domain-core | Remove CODEBASE.md |
| app-core #1 | app-core | Remove CODEBASE.md |

### Graphify Graph (initial build)

- Nodes: 5,268 | Edges: 10,450 | Communities: 421 | Source files: 767
- Token reduction: 256x vs naive full-corpus reads
- God nodes: `buildDay2Scheme()` (97), `newScheme()` (78), `NewRegistry()` (77)
- Graph at: `~/ontai/graphify-out/graph.json`
- Agents must run `/graphify --update` after every codebase change

---

## Session/20 Work (2026-05-03) -- MERGED

### PRs Merged (session/20)

| PR | Repo | Branch | Summary |
|----|------|--------|---------|
| conductor #34 | conductor | session/19-compiler-fixes | Management bootstrap guard, OCI push auth (docker config.json + snap fallback), cluster-input-tenant.yaml machineConfigPaths fix, BACKLOG COMPILER-BL-TALOSCLUSTER-VIP-REMOVAL |
| ontai #15 | ontai | session/19-site-schema-update | ontai.dev: schema stats 36 schemas, seam-core 12 types, LineageController badge Alpha: Partial |

### LineageController Confirmed

LineageController working for all 9 GVKs: 4 infrastructure.ontai.dev types (InfrastructureTalosCluster, InfrastructureClusterPack, InfrastructurePackExecution, InfrastructurePackInstance) and 5 security.ontai.dev types (RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet). Initial concern about security.ontai.dev types was transient; all synced correctly.

---

## Session/19 Work (2026-05-03) -- MERGED

### PRs Merged (session/19)

| PR | Repo | Branch | Summary |
|----|------|--------|---------|
| conductor #31 | conductor | session/18-kube-upgrade-fix | kube-upgrade v-prefix fix, GetMachineConfig+merge pattern, 2 new unit tests |
| conductor #32 | conductor | session/18-k8s-drift-to-main | Cherry-pick KubernetesVersionDriftLoop to main (PR #30 had landed on session/17 branch) |
| conductor #33 | conductor | session/19-onboarding-runbook | Onboarding runbook and 5 config files in conductor/docs/configs/ |
| ontai-schema #9 | ontai-schema | session/19-schema-index-update | schema index: seam-core 3->12 schemas, v1.9.3-alpha.1, Decision G migration |
| ontai #14 | ontai | session/19-site-alpha-release | ontai.dev: hero stat v1.9.3-alpha.1, operator cards updated, submodule bump |

### Alpha Release

- Tag: v1.9.3-alpha.1 on conductor repo
- GitHub release created

### ccs-dev Node Recovery

- Nodes had kubelet:1.32.3 (no v) in machine config after first corrective Job run
- Applied talosctl machine config patch (no-reboot mode) to all 3 nodes replacing 1.32.3 with v1.32.3
- All nodes returned to Ready at v1.32.3
- DriftSignal drift-k8s-version-ccs-dev confirmed

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
2. K8s drift signal confirm -- drift-k8s-version-ccs-dev is queued; nodes are at v1.32.3 and should be confirmed once platform UpgradePolicyReconciler verifies convergence.
3. MGMT-HP-NODE test fix -- `ccs-mgmt-w2` hardcoded node does not exist; decide whether single-node targeting should be implemented.
4. Phase 6 (T-20, T-21) -- day2 scheduling with node awareness; design session required.
5. COMPILER-BL-TALOSCLUSTER-VIP-REMOVAL -- remove mutable clusterEndpoint VIP field from InfrastructureTalosCluster CR and compiler emit paths; schema PR to ontai-schema first (Decision 11); deferred post-alpha.
6. LineageSink, IdentityProvider, IdentityBinding -- future scope; deferred past alpha.
