# ONT Platform Progress

**Last updated:** 2026-05-06 (session/25b)
**Full session archive:** PROGRESS-archive-2026-04-20.md

> Understand the codebase through graphify, not this file:
> - Production graph: `~/ontai/graphify-out/graph.json` -- 2,787 nodes, 4,383 links, 266 communities
> - Test graph: `~/ontai/graphify-tests-out/graph.json` -- 2,282 nodes, 4,968 links
> - Build test graph: `python graphify-tests.py` from ontai root
> - Update production graph: `/graphify --update` from ontai root after any code change

---

## Current Platform State

**Alpha release:** v1.9.3-alpha.1 (conductor repo tag, shipped session/19)

**All six operators ship and reconcile:**

| Operator | Repo | Status |
|----------|------|--------|
| guardian | guardian | Operational. RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet, PermissionSnapshot, APIGroupSweep all reconciling. Admission webhook live. |
| platform | platform | Operational. TalosCluster lifecycle, CAPI provider, all day-2 job CRDs, DriftSignalReconciler for RunnerConfig/Talos/K8s drift, Decision H cascade. |
| conductor | conductor | Operational. 18 capabilities registered. Execute + agent modes. Signing loop, pack receipt loop, snapshot loop, drift handler, K8s/Talos version drift loops, federation. |
| wrapper | wrapper | Operational. ClusterPack, PackExecution, PackInstance reconcilers. ConductorReady gate. Drift cascade delete. |
| seam-core | seam-core | Operational. LineageController across all 9 GVKs. DriftSignal CRD. Conditions package. |
| domain-core | domain-core | Operational. Layer 0 abstract types. DomainLineageIndex. No controllers. |

**Test infrastructure:**
- Unit tests: all repos green
- Integration tests (envtest): all repos green. Run with `KUBEBUILDER_ASSETS=$(make -s envtest-path)` from any repo. Setup: `make envtest-setup` from ontai root (K8s 1.32.x, matches ccs-mgmt).
- e2e: Cluster-dependent; gates on `MGMT_KUBECONFIG` env var. Most specs are live-promoted stubs.

---

## Open PRs (Pending Merge)

None.

---

## Infrastructure Status

| Cluster | Status | Impact |
|---------|--------|--------|
| ccs-mgmt | Partially degraded -- cp3 NotReady, Talos API down | Conductor pod CrashLoopBackOff; blocks MGMT-HP-NODE e2e |
| ccs-dev (10.20.0.20) | Unreachable | Blocks all TENANT day-2 e2e: HP-CLUSTER, HP-NODE, PKI-CLUSTER-REACH |
| drift-k8s-version-ccs-dev | Closed (session/25b) | Validated via synthetic injection. Both spec copies reverted to 1.32.3. DriftSignal and UpgradePolicy deleted. |

---

## Session/25b (2026-05-06) -- K8S-DRIFT-CONFIRM + live e2e validation

**K8S-DRIFT-CONFIRM (closed)**
Kubernetes version drift detection loop validated via synthetic injection on ccs-dev.
- Deleted stale `drift-k8s-version-ccs-dev` DriftSignal and both UpgradePolicies from session/18.
- Patched `spec.kubernetesVersion=1.32.2` on tenant-local `InfrastructureTalosCluster ccs-dev` (ont-system on ccs-dev cluster).
- Conductor k8s version drift loop detected mismatch (spec=1.32.2 vs observed=1.32.3) within ~15s.
- `drift-k8s-version-ccs-dev` DriftSignal created in `seam-tenant-ccs-dev` with correct driftReason.
- `DriftSignalReconciler` processed signal, advanced to `queued`.
- Root cause of no UpgradePolicy: `DriftSignalReconciler.handleTalosVersionDrift` parses Talos version format only; k8s drift reason format differs. Detection loop confirmed; automatic corrective UpgradePolicy for k8s drift is not yet implemented (future item).
- Reverted both spec copies to 1.32.3 and deleted synthetic signal.

**Live e2e (session/25 + 25b)**
- machineconfig-backup triggered on ccs-mgmt and ccs-dev: S3 artifacts confirmed at `seam-backups/{cluster}/machineconfigs/{ts}/{hostname}.yaml`.
- machineconfig-restore from backup timestamp on both clusters: all nodes remained Ready post-restore.
- Both PRs (conductor #41, platform #26) merged.

---

## Session/25 (2026-05-06) -- machineconfig-restore + backup schedule reconcilers

All Task 1 deliverables complete. All unit and integration tests green.

**`PLATFORM-BL-MACHINECONFIG-RESTORE` (closed)**
`TalosMachineConfigRestore` CRD added to platform API. `MachineConfigRestoreReconciler` implements the operational Job pattern: gates on RunnerConfig/capability, resolves S3 secret, projects env secret, submits Conductor executor Job, polls OperationResult. One-shot CR (does not requeue on Succeeded). Conditions: `MachineConfigRestoreReady`, `MachineConfigRestoreRunning`, `MachineConfigRestoreDegraded`, `MachineConfigRestoreS3Absent`, `CapabilityUnavailable`.

**`TalosMachineConfigBackupSchedule` + `TalosEtcdBackupSchedule` (new CRDs and reconcilers)**
Interval-based scheduler pattern: `time.ParseDuration` + `RequeueAfter`. `MachineConfigBackupScheduleReconciler` creates `TalosMachineConfigBackup` CRs named `{cluster}-sched-{ts}`. `EtcdBackupScheduleReconciler` creates `EtcdMaintenance` CRs with `operation=backup`. No external cron dependency.

**conductor: `machineconfig-restore` capability (closed)**
`machineConfigRestoreHandler.Execute()`: reads `TalosMachineConfigRestore` CR, downloads per-node config from S3 at `{cluster}/machineconfigs/{ts}/{hostname}.yaml`, applies via `ApplyConfiguration`, waits for node stable. Non-fatal per node; returns `ExecutionFailure` only when all nodes fail. `CapabilityMachineConfigRestore` constant added to `pkg/runnerlib/constants.go`. 5 unit tests: nil clients, no CR, success, download failure, targetNodes filter -- all pass.

**Registrations:** All 3 new reconcilers registered in `platform/cmd/platform/main.go`.

**PRs:** conductor #41, platform #26 -- both open, CI running.

---

## Session/24b (2026-05-06) -- HardeningProfile bootstrap support

`PLATFORM-BL-HARDENINGPROFILE-MERGE` implemented end to end. All unit + integration tests green. Both graphs rebuilt.

**ontai-schema:** `hardeningProfileRef` (optional LocalObjectRef) added to `InfrastructureTalosCluster.json`. `HardeningApplied` added to status conditions list.

**seam-core:** `HardeningProfileRef *InfrastructureLocalObjectRef` field added to `InfrastructureTalosClusterSpec` in `taloscluster_types.go`. `DeepCopyInto` updated. `ConditionTypeHardeningApplied`, `ReasonHardeningApplied`, `ReasonHardeningPending`, `ReasonHardeningProfileNotValid` added to `seam-core/pkg/conditions/conditions.go`.

**platform CAPI path:** `ensureTalosConfigTemplate` now reads `HardeningProfile` when `hardeningProfileRef` is set: merges `SysctlParams` into the CP-INV-009 base sysctl map, parses and appends `MachineConfigPatches` as JSON patch objects. `reconcileCAPIPath` sets `HardeningApplied=True` after the template step when profile is referenced.

**platform ONT-native path:** `ensureBootstrapHardening` in `taloscluster_bootstrap_hardening.go`. Called from main reconcile loop (Step G) after route result, for non-CAPI Ready clusters with `hardeningProfileRef` set. Creates `NodeMaintenance` (operation=hardening-apply, label `ontai.dev/hardening-trigger=bootstrap`) in `seam-tenant-{cluster}`. Sets `HardeningApplied=False/HardeningPending` while pending; `HardeningApplied=True` when `NodeMaintenance.Ready=True`. Validates `HardeningProfile.Valid=True` before creation. Returns `RequeueAfter: 30s` while pending.

**4 unit tests:** NilRef, CreatesNodeMaintenance, NoDuplicate, SetsAppliedWhenReady -- all pass.

**Graph stats:** Production 2,787 nodes / 4,383 links; Test 2,282 nodes / 4,968 links.

---

## Session/24 (2026-05-06) -- Bootstrap cleanup implemented

Three platform defects fixed and one machineconfig framing corrected. All unit + integration tests green. Both graphify graphs rebuilt.

**`PLATFORM-BL-TALOSCONFIG-ONTYSYSTEM-REMOVE` (closed)**
`ensureExecutorTalosconfig` now copies talosconfig only to `seam-tenant-{cluster}`. Removed the `ont-system` destination: day-2 executor Jobs run in `seam-tenant-{cluster}` and mount from that namespace (`operational_job_base.go:L64`). The conductor agent Deployment reads `TALOSCONFIG_PATH` from the enable bundle -- not from this copy.

**`PLATFORM-BL-KUBECONFIG-CANONICAL` (closed)**
Canonical kubeconfig is now `seam-mc-{cluster}-kubeconfig` everywhere:
- Deleted `tenantKubeconfigSecretName` constant and `ensureTenantKubeconfigCopy` from `taloscluster_import_helpers.go`
- Added `ensureCAPIKubeconfig` helper in `taloscluster_helpers.go`
- `EnsureRemoteConductorBootstrap` reads `kubeconfigSecretName(tc.Name)` for both import and CAPI paths (no mode bifurcation)
- `platform_security.go` PKI rotation writes only `seam-mc-{cluster}-kubeconfig`
- e2e test `pkirotation_e2e_test.go` checks canonical name

**`PLATFORM-BL-CAPI-TENANT-ONBOARDING` (closed)**
Added step 8.5 in `reconcileCAPIPath` (`taloscluster_controller.go`) after CAPI Running confirmed:
1. `ensureCAPITalosconfig`: copies `{cluster}-talosconfig` (TALM output) → `seam-mc-{cluster}-talosconfig`
2. `ensureCAPIKubeconfig`: copies `{cluster}-kubeconfig` (CAPI output) → `seam-mc-{cluster}-kubeconfig`
3. `ensureTenantOnboarding`: registers RBACPolicy, 4 RBACProfiles, LocalQueue, platform-executor SA/RBAC, wrapper-runner SA/RBAC

**Machineconfig reframe (`PLATFORM-BL-MACHINECONFIG-BACKUP`)**
`hardeningApplyHandler` and `kubeUpgradeHandler` confirmed to use live Talos API (`GetMachineConfig` + `ApplyConfiguration`) -- no stored machineconfig secrets are read by any day-2 op. The `PLATFORM-BL-MACHINECONFIG-IMPORT-CAPTURE` framing was wrong. Replaced with `PLATFORM-BL-MACHINECONFIG-BACKUP`: new conductor capability + `TalosMachineConfigBackup` CRD storing `{bucket}/{cluster}/machineconfigs/{TIMESTAMP}/{hostname}.yaml`, mirroring the etcd backup structure.

**`PLATFORM-BL-MACHINECONFIG-BACKUP` (closed)**
`machineconfig-backup` Conductor capability added in `platform_machineconfig.go`. Reads each node's running config via `GetMachineConfig` (per-node `NodeContext` + `EndpointsFromTalosconfig` for production, single-node fallback for tests), uploads to S3 at `{cluster}/machineconfigs/{TIMESTAMP}/{hostname}.yaml`. Hostname extracted from config YAML; falls back to sanitized node IP when absent. `TalosMachineConfigBackup` CRD added to platform API (`machineconfigbackup_types.go`), DeepCopy methods added to `zz_generated.deepcopy.go`. `MachineConfigBackupReconciler` mirrors `EtcdMaintenanceReconciler`: RunnerConfig gate, S3 credential projection via new generic `ensureS3EnvSecretFor`/`resolveS3BackupSecretRef` helpers in `s3_env_secret.go`. Reconciler registered in `main.go`. 5 unit tests pass. `machineconfig-restore` deferred.

**Graph stats:** Production 2,785 nodes / 4,382 links; Test 2,274 nodes / 4,950 links.

---

## Session/23b (2026-05-05) -- Bootstrap gap analysis

Queried graphify and read source to map the CAPI tenant cluster bootstrap gap against the working import path.

**Finding:** `reconcileCAPIPath` creates the `seam-tenant-{cluster}` namespace and deploys conductor but never calls `ensureTenantOnboarding`. Three concrete missing steps identified and captured as `PLATFORM-BL-CAPI-TENANT-ONBOARDING` (high priority):

1. **Talosconfig name translation** -- `{cluster}-talosconfig` (TalosControlPlane output) must be copied to `seam-mc-{cluster}-talosconfig` before `ensureExecutorTalosconfig` is called; otherwise it silently no-ops and day-2 Jobs that need talosconfig fail.
2. **Kubeconfig canonical name** -- `{cluster}-kubeconfig` (CAPI output) must be copied to `target-cluster-kubeconfig` in `seam-tenant-{cluster}`; conductor-execute Jobs mount this fixed name (`platform_security.go:L183`).
3. **Full tenant onboarding** -- `ensureTenantOnboarding` is never called: RBACPolicy, 4 RBACProfiles, LocalQueue, platform-executor SA/Role/RoleBinding, wrapper-runner SA/Role/RoleBinding all absent, blocking pack delivery and all day-2 ops.

**Management cluster bootstrap (`reconcileDirectBootstrap`, mode=bootstrap):** Confirmed complete. Namespace, talosconfig, kubeconfig, RBAC, and Ready transition all handled correctly via `ensureManagementOnboarding`.

**Machineconfig capture** (`PLATFORM-BL-MACHINECONFIG-IMPORT-CAPTURE`) updated to cover both import and CAPI paths; gates on `PLATFORM-BL-CAPI-TENANT-ONBOARDING` closing first.

---

## Session/23 (2026-05-05)

Two tasks:

**Task 1 -- Test-only graphify graph**
- `graphify-tests.py` at ontai root collects all `*_test.go` + `test/` Go files from every repo
- First run: 227 files, 2,247 nodes, 4,914 links, 165 communities (per-operator suites, scheme builders, fake clients, integration/e2e structure)
- `graphify-tests-out/` added to `.gitignore` -- generated output, never committed
- CONTEXT.md updated with two-graph model

**Task 2 -- Envtest local setup**
- `make envtest-setup` in root Makefile: installs etcd + kube-apiserver for K8s 1.32.x to `~/.local/share/kubebuilder-envtest`. Pinned to ccs-mgmt version (talosVersion v1.9.3 -> k8s 1.32.3).
- `make envtest-path` prints `KUBEBUILDER_ASSETS` for shell eval.
- All integration suites confirmed green: guardian (4), conductor (3), platform (2), wrapper (1), seam-core (1).
- `suite_test.go` comments updated in conductor, platform, wrapper.

**BACKLOG cleanup (this session):**
- Closed T-23 (DriftSignalReconciler implemented), T-24 (Decision H cascade implemented), GUARDIAN-AUTO-RBAC (APIGroupSweepController implemented)
- Added graphify query refs to every open backlog item

---

## Session/22 (2026-05-05)

Six cleanup items, all merged:

| PR | Summary |
|----|---------|
| wrapper via ontai #18 | Delete wrapper TCOR CRD YAML (Decision G violation) |
| ontai #19 | Remove ont-lab/ directory and root .gitignore entry |
| conductor #37 | hardeningApply VIP fix: ClusterEndpoint filter + waitForNodeStable + 3 unit tests |
| platform #22 | Drop PlatformTenant forward reference from CLAUDE.md Step 4b |
| ontai #20 | `.graphifyignore` + graph rebuild: 5,268 -> 2,755 nodes (test/lab ghost nodes pruned) |
| conductor #38 | NewRegistry dual-mode usage comment |

---

## Session/21 (2026-05-04)

Graphify replaces CODEBASE.md as source of truth across all repos. 8 PRs merged (one per repo). Graph initial build: 5,268 nodes, 10,450 edges, 421 communities, 767 source files.

---

## Session/20 (2026-05-03)

- conductor PR #34: management bootstrap guard, OCI push auth, tenant config fix
- LineageController confirmed across all 9 GVKs
- ontai.dev site: schema stats updated

---

## Session/19 (2026-05-03)

- Alpha release v1.9.3-alpha.1 cut and tagged
- Onboarding runbook merged (conductor #33)
- ccs-dev node recovery: kubelet v-prefix applied, nodes back to Ready at v1.32.3
- K8s version drift: DriftSignal queued, corrective UpgradePolicy exists

---

## Session/17+18 (2026-05-02)

- PKI rotation automation (seam-core #16, conductor #29)
- KubernetesVersionDriftLoop (conductor #30)
- DriftSignal live e2e (ccs-dev): 6-step cycle validated
- K8s version drift live e2e: out-of-band upgrade detected; corrective policy created, Job pending
- Three bugs fixed: DriftSignal on terminating namespaces, packDeployHandler alphabetical-first-match, wrapper RunnerConfig GVK
- PE ownerRef gap closed: ClusterPackReconciler re-creates PE on external deletion
