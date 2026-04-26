# ONT Platform Progress

**Current state:** Phase 2B complete. Day-2 operations on ccs-mgmt validated including PKI rotation end-to-end. conductor-execute image split implemented (executor=conductor-execute:dev, agent=conductor:dev). Machine config capture after node ops implemented. TCOR CRD in enable bundle base phase; platform-permissions PermissionSet updated. TCOR design correction from Governor: TCOR is a single per-cluster accumulated CR, not per-operation -- requires schema redesign before next day-2 session. Next gate: TENANT-CLUSTER-E2E.

**Full history:** PROGRESS-archive-2026-04-20.md

---

## Phase 2B -- Seam-core CRD Migration (COMPLETE 2026-04-25)

All seven infrastructure types migrated from conductor and wrapper into seam-core under `infrastructure.ontai.dev/v1alpha1`:

| Type | Migrated From |
|------|---------------|
| InfrastructureRunnerConfig | conductor (runner.ontai.dev) |
| InfrastructurePackReceipt | conductor (runner.ontai.dev) |
| InfrastructureClusterPack | wrapper (infra.ontai.dev) |
| InfrastructurePackExecution | wrapper (infra.ontai.dev) |
| InfrastructurePackInstance | wrapper (infra.ontai.dev) |
| InfrastructurePackBuild | wrapper (infra.ontai.dev) |
| InfrastructureTalosCluster | platform (platform.ontai.dev) |

- T-2B-0: PackReceipt vs PackOperationResult separation decision. CLOSED.
- T-2B-1 through T-2B-4: Four ontai-schema PRs (#4 through #7). All merged.
- T-2B-5: seam-core Go types added. PR #11 merged.
- T-2B-6: Conductor import migration (remove RunnerConfig/PackReceipt, import seam-core). PR #20 merged.
- T-2B-7: Wrapper import migration (remove ClusterPack/PackExecution/PackInstance, import seam-core). PR #12 merged.
- T-2B-8: Platform import migration (remove unstructured RunnerConfig workaround). Merged.
- T-2B-9: CRD manifest migration -- removed CRD YAML from conductor/wrapper config/crd; migrated dynamic GVR constants to infrastructure.ontai.dev. conductor commit faf8e72, wrapper commit 2807054.

---

## Current Branch Work

### session/phase2b (wrapper -- pushed, PR pending)

**Gate 4 deadlock fix (CLOSED):**
`isRBACProfileProvisioned` returned false on NotFound, blocking Conductor Job submission. The Conductor Job creates the RBACProfile via rbac-intake -- circular deadlock. Fixed: NotFound returns true; only blocks when profile EXISTS with provisioned=false. Unit test: `TestPackExecutionReconciler_Gate4_AbsentProfileAllowsJobSubmission`. wrapper commit e621e22.

**POR ownerRef Kind fix (CLOSED):**
All 3 ownerRef constructions in `packexecution_reconciler.go` used pre-Phase2B Kind `"PackExecution"`. Kubernetes GC resolves by GVK; wrong Kind broke cascade deletion of PackOperationResult when PackExecution was deleted. Fixed to `"InfrastructurePackExecution"` (3 occurrences). Two unit test kind assertions updated. wrapper commit e621e22.

**Additional bakes on session/phase2b:**
- T-2B-9 wrapper CRD manifest migration (commit 2807054)
- Gate 5 SAR: `RBACReadyChecker` hook field on PackExecutionReconciler, bypassed in unit tests via `rbacAllowedStub`
- Stale Job detection fix: `newJob` helper sets ownerRef so pre-seeded test jobs are not considered stale
- TalosCluster GVK fix in test/unit package: infrastructure.ontai.dev/InfrastructureTalosCluster
- signing_loop_test.go spec field fix, packreceipt_test.go seam-core types cleanup

### session/phase1 (ontai root -- pushed)

**Enable bundle Layer 1 naming alignment (CLOSED):**
- `guardian-permissionsets.yaml`: renamed seam-bootstrap-ceiling to management-maximum; added `ontai.dev/policy-type: management` label.
- `guardian-rbacpolicy.yaml`: renamed seam-platform-rbac-policy to management-policy; dropped allowedClusters; added policy-type label.
- All `rbacPolicyRef` occurrences in guardian-rbacprofiles.yaml, platform-wrapper-rbacprofiles.yaml (x3), conductor-rbacprofile.yaml updated to management-policy.
- Enforces CS-INV-008 Layer 1 naming. ontai root commit e82caf2.

**INV-023 added (CLOSED):**
Operator Deployments and enable bundles always reference `:dev` tag in lab/development. Custom per-build tags never written into committed artifacts. Amendment history updated.

**Three-bucket manifest split (CLOSED -- landed in session/14):**
conductor `SplitManifests` returns three slices (rbac, clusterScoped, workload). Eight cluster-scoped kinds. `executeSplitPath` gains step 6 for cluster-scoped layer. `writeWrapperRunnerRBACYAML` emits `wrapper-runner-cluster-scoped` ClusterRole + ClusterRoleBinding covering admissionregistration, apiextensions, storage, scheduling, ingressclasses, cert-manager.io. conductor PR #18, wrapper PR #11.

**Enable bundle other bakes (CLOSED -- landed in session/14):**
- `wrapper-runner.yaml`: PackOperationResult RBAC rule baked into compiler template. Regenerated for ccs-mgmt and ccs-dev.
- `wrapper-runner-cluster-scoped` ClusterRole/CRB: added to enable bundle for bucket 2 resources.
- `platform-wrapper-deployments.yaml`: DSNS_SERVICE_IP=10.20.0.240.
- `dsns-loadbalancer.yaml`: Cilium LB-IPAM annotation.
- `conductor-signing-key.yaml`: Ed25519 signing key rotated.
- seam-core lab additions: WrapperRunnerRBACNotReady condition, Ready printcolumn on InfrastructureTalosCluster, Dockerfile COPY path fix.

### session/14-third-party-profiles (guardian -- in progress)

**Guardian crash root cause (CLOSED 2026-04-26):**
- `ClusterRBACPolicyReconciler` (PR #15) watches InfrastructureTalosCluster and SeamMembership.
  The compiled guardian-manager-role ClusterRole granted only `get` on infrastructurerunnerconfigs.
  Missing: list/watch on infrastructuretalosclusters and list/watch/create/update/delete on
  seammemberships. API server returned 403 causing informer cache sync timeouts. `mgr.Start()` failed.
- Fix: added two PolicyRule blocks to `operatorClusterRules("guardian")` in compile_enable.go.
  Regenerated guardian-rbac.yaml for both ccs-mgmt and ccs-dev. conductor PR #25.
- Apply fix: `kubectl apply --server-side -f lab/configs/ccs-mgmt/compiled/enable/01-guardian-bootstrap/guardian-rbac.yaml`

**Three-layer RBAC hierarchy locked (CLOSED 2026-04-26):**
- guardian-schema.md §19 completely replaced with authoritative structural specification.
  Exactly two canonical PermissionSet names: management-maximum (Layer 1) and cluster-maximum (Layer 2).
  No per-operator and no per-component PermissionSets. Seam operator profiles reference management-maximum.
  Component profiles reference cluster-maximum. CS-INV-009: cluster-policy validation at creation time only.
  IdentityProvider chain formally documented. Management cluster dual-layer case documented.
- guardian/CLAUDE.md CS-INV-008 and CS-INV-009 updated. guardian commit 0fc7333.
- **Known defect (OPEN):** compiler writeBootstrapPermissionSets still generates per-operator PermissionSets.
  buildOperatorRBACProfile still emits permissionSetRef: {op.Name}-permissions instead of management-maximum.
  Named in amendment log. Follow-up compiler fix session required before any enable bundle regeneration.

**§20 Import-Mode Tenant Cluster Onboarding (CLOSED 2026-04-26):**
- guardian-schema.md §20 added: complete sequencing for import-mode cluster admission.
  Covers compiler output (InfrastructureTalosCluster CR only), guardian Layer 2 creation,
  Platform two-site orchestration, conductor RBACProfile as Seam operator profile
  (rbacPolicyRef: management-policy, permissionSetRef: management-maximum in ont-system),
  gRPC handshake protocol, PermissionSnapshot delivery/verification, and severance sequence.
- platform-schema.md §12 extended with import-mode specifics. platform branch session/14-import-mode-docs.
- conductor-schema.md §15 extended with tenant gRPC handshake sequence. conductor commit 284c051.
- guardian commit 9e12e02 pushed on session/14-third-party-profiles.

**Lab 3-node CP-only invariant (CLOSED 2026-04-26):**
- lab/CLAUDE.md updated (gitignored, on disk only):
  - LAB-INV-001 added: both clusters are 3-node CP-only, no worker nodes.
  - Cluster registry IP ranges corrected: ccs-mgmt 10.20.0.2-4, ccs-dev 10.20.0.11-13.
  - ccs-dev VIP corrected from 10.20.0.15 to 10.20.0.20 (matches machineconfig).
  - Worker MAC table rows removed for ccs-mgmt-w1/w2 and ccs-dev-w1/w2.

### session/14-bake-lab-patches (conductor -- in progress)

**conductor-execute image split (CLOSED 2026-04-26):**
- `conductorExecuteImageName = "conductor-execute"` constant added to platform `taloscluster_helpers.go`
- `executorImageTag(talosVersion)` helper: returns `"dev"` in lab (devRevision=dev), returns `talosVersion` in production
- `ensureBootstrapRunnerConfig` and `submitBootstrapJob` now write `conductor-execute:dev` to RunnerConfig.spec.runnerImage
- Conductor agent Deployment image stays `conductor:dev`
- Unit test assertion updated from `conductor:v1.9.3-dev` to `conductor-execute:dev`

**Machine config capture (CLOSED 2026-04-26):**
- `GetMachineConfig(ctx)` added to `TalosNodeClient` interface; implemented via Talos `Read()` at `/system/state/config.yaml`
- `captureMachineConfigSecret` helper in `platform_node.go`: parses hostname from config YAML, writes `seam-mc-{cluster}-{hostname}` Secret in `seam-tenant-{cluster}` with key `machineconfig`
- `nodePatchHandler.Execute` calls capture as final step after `ApplyConfiguration` succeeds
- Non-fatal: capture failure logged as skipped step, does not fail the capability

**PKI rotation fix (CLOSED 2026-04-26):**
- Replaced invalid minimal CA config with `GetMachineConfig()` + `ApplyConfiguration(staged)` pattern
- Validated end-to-end: `pki-rotate-lab-01` TCOR shows `Succeeded`, message "config staged for next reboot"
- `compile_enable.go`: `operatorClusterRules("platform")` and `writePlatformExecutorRoleFile` both add secrets rule

**TCOR in enable bundle (CLOSED 2026-04-26):**
- `seam-core-crds.yaml`: TCOR CRD appended to base phase `00-infrastructure-dependencies`
- `guardian-permissionsets.yaml`: `platform-permissions` PermissionSet gains TCOR get/list/watch/create/update/patch/delete
- Root ontai commit `bff1081`

**Compiler Phase 2B type migration and cluster-role fix (CLOSED 2026-04-26):**
- `compile.go` and `compile_packbuild_helm.go`: import migrated from `wrapper/api/v1alpha1` to `seam-core/api/v1alpha1`; ClusterPack struct and spec types updated to InfrastructureClusterPack (infrastructure.ontai.dev). Phase 2B had emptied the wrapper package but the compiler still referenced it.
- `compile_enable.go`: `conductorOp()` hardcoded `role: management` -- silent misbehavior for tenant clusters. Added `clusterRole string` parameter and `--cluster-role` CLI flag. Compiler now emits CONDUCTOR_ROLE=tenant for ccs-dev enable bundle.
- `compile_packbuild_test.go`, `compile_launch_test.go`: stale API group expectations updated from infra.ontai.dev/runner.ontai.dev to infrastructure.ontai.dev.
- `compile_enable_test.go`: all 43 call sites updated to pass eighth argument (defaults to management).
- conductor commit `e18cdf5`

**Phase B script: enable bundle wiring for ccs-dev (CLOSED 2026-04-26):**
- `lab/scripts/phase-b-dev-import.sh`: step 4.5 inserted between API-reachable check and AC-2 wrapper e2e run. Applies all six enable phases from `lab/configs/ccs-dev/compiled/enable/` to ccs-dev via DEV_KUBECONFIG.
- `lab/Makefile`: `dev-tenant-enable` target added -- applies compiled enable bundle to ccs-dev standalone.
- `lab/configs/ccs-dev/compiled/enable/04-conductor/conductor-deployment.yaml`: annotation fixed from `role: management` to `role: tenant`; comment updated from CONDUCTOR_ROLE=management to CONDUCTOR_ROLE=tenant.
- ontai root commit to follow.

**TCOR design correction (OPEN -- Governor directive 2026-04-26):**
- Current implementation treats TCOR as a per-operation CR (one per Job). This is incorrect.
- Correct design: one TCOR per cluster, created on InfrastructureTalosCluster admission, operations appended as a list. Revision tied to talosVersion. On version upgrade, N-1 revision data dumped to graphQuery DB and deleted. Revisions linked across InfrastructureTalosCluster and InfrastructureClusterPacks. Dumped data = infrastructure memory.
- Required: seam-core schema PR (Decision 11, Decision G) before any platform/conductor changes.
- Tracked as TCOR-DESIGN-REVISION in BACKLOG.md.

**Permission hardening (CLOSED 2026-04-25):**
- `writeBootstrapPermissionSets` rewritten: management-maximum replaces seam-bootstrap-ceiling (Layer 1 ceiling), five operator PermissionSets now emit scoped least-privilege rules (no wildcard apiGroups) instead of bootstrap wildcards. guardian-schema.md §6, §19; CS-INV-008.
- `writeBootstrapRBACPolicy` rewritten: management-policy replaces seam-platform-rbac-policy; allowedClusters removed; ontai.dev/policy-type: management label added; maximumPermissionSetRef corrected to management-maximum.
- `rbacPolicyRef` in `buildOperatorRBACProfile` updated to management-policy.
- Five new tests: `TestEnable_BootstrapRBACPolicyName`, `TestEnable_BootstrapPermissionSetNames`, `TestEnable_ManagementMaximumHasPolicyTypeLabel`, `TestEnable_OperatorPermissionSetsAreScoped`, `TestEnable_RBACProfilesRefManagementPolicy`.
- ccs-mgmt and ccs-dev enable bundle files regenerated.
- New scoped PermissionSets applied to live cluster; guardian re-provisioned all five RBACProfiles with scoped ClusterRoles. conductor commit 2906355.
- Note: bind/escalate verbs rejected by PermissionSet schema; guardian's RBAC escalation capability comes from bootstrap ClusterRole in guardian-rbac.yaml.

---

## Management Cluster Validation (ccs-mgmt)

All tests run against ccs-mgmt. Management cluster is treated as a tenant for pack delivery (seam-tenant-ccs-mgmt namespace for pack delivery, security CRs).

| # | Test | Status | Notes |
|---|------|--------|-------|
| 1 | Initial pack deploy (nginx v4.9.0-r1): 6-step split path, RBACProfile provisioned=true, PackExecution Succeeded | PASS | session/13-clusterpack-rbac-split |
| 2 | PackOperationResult created with upgradeDirection=Initial | PASS | session/13-pack-operation-result |
| 3 | Pack upgrade (v4.9.0-r1 to v4.10.0-r1): upgradeDirection=Upgrade | PASS | session/13-pack-operation-result |
| 4 | Pack rollback (v4.10.0-r1 to v4.9.0-r1): upgradeDirection=Rollback | PASS | session/13-pack-operation-result |
| 5 | Pack redeploy (same version): upgradeDirection=Redeploy | PASS | session/13-pack-operation-result |
| 6 | ValuesFile field recorded in ClusterPack CR spec | PASS | session/14 WS12; required wrapper rebuild after seam-core ValuesFile addition |
| 7 | Pack upgrade N→N+1 single-active-revision: r2 created, r1 deleted, one POR survives | PASS | session/14 WS12 |
| 8 | PE deletion cascades POR via GC (ownerRef Kind fix required) | PASS | session/14 WS12 |
| 9 | ClusterPack redeploy after PE+POR deletion starts at r1 | PASS | session/14 WS12 |
| 10 | EtcdMaintenance defrag: Running=True then Ready=True | PASS | session/phase2b; required Pod informer fix, conductor rebuild, TCOR CRD install, executor SA/RBAC setup |
| 11 | ClusterMaintenance window: WindowActive=False (outside window) | PASS | session/phase2b |
| 12 | NodeOperation reboot ccs-mgmt-w2: JobName set, capability Succeeded | PASS | session/phase2b |
| 13 | NodeMaintenance node-patch ccs-mgmt-w2: JobName set, capability fails (no patchSecretRef -- correct validation) | PASS | session/phase2b |
| 14 | PKIRotation end-to-end: pki-rotate-lab-01 TCOR Succeeded; GetMachineConfig+staged apply | PASS | session/14-bake-lab-patches |
| 15 | UpgradePolicy via spec.versionUpgrade: UpgradePolicy auto-created, VersionUpgradePending=True | PASS | session/phase2b |
| 16 | Machine config capture: captureMachineConfigSecret writes seam-mc-{cluster}-{hostname} Secret after node-patch | IMPL | session/14-bake-lab-patches; node-patch full e2e blocked by patchSecretRef |

**Helm chart upgrade path:** nginx-ingress v4.9.0 → v4.10.0 upgrade tested and passing (test 3 above). This satisfies the helm upgrade e2e requirement.

**ClusterPack reconciler retrigger note:** ClusterPackReconciler does not watch PE deletions. After manual PE deletion, add annotation `ontai.dev/retrigger=$(date +%s)` on the ClusterPack to force re-reconciliation.

---

## Open Work

### Backlog items blocking alpha

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Prerequisite for alpha. Requires ccs-dev VMs and compiler bootstrap run for ccs-dev. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull RBACProfile from management cluster seam-tenant-{tenantCluster} and write into ont-system on tenant cluster. Governor design session required before implementation. |

### Backlog items for next session

| ID | Component | Description |
|----|-----------|-------------|
| DAY2-OPS-MGMT | conductor, platform | CLOSED (session/phase2b). All 6 day-2 operation types validated on ccs-mgmt. Remaining gaps: node-patch needs patchSecretRef secret; pki-rotation needs proper CA talosconfig; cluster-reset not manually tested (requires reset-approved annotation). |
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | Reconciler sweep to back-fill RBACProfiles for RBAC resources arriving outside rbac-intake (bootstrap apply, pre-split packs). Governor design session required. |
| PLATFORM-BL-3-LOCALQUEUE | platform | Platform must create LocalQueue in seam-tenant for tenant clusters. Currently only management cluster gets it from compiler phase 05. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately on capability publication rather than 30s requeue. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management should cover ccs-mgmt. Eliminates redundant snapshot-ccs-mgmt. |
| WRAPPER-BL-ENVTEST-GC | wrapper | TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted requires kube-controller-manager GC. Promote when cluster e2e suite is established. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | PackInstance deletion triggers ClusterPack reconcile with PackExecution cascade. Verify no regression after Phase 2B. |

---

## Next Session Candidates

1. **TENANT-CLUSTER-E2E** -- ccs-dev onboarding. Promotes all AC-2/AC-4/AC-5 e2e stubs to live. First step: compiler bootstrap run for ccs-dev.
2. **TCOR-DESIGN-REVISION** -- Governor correction: TCOR is one per cluster, not per operation. Requires seam-core schema PR before any operator changes. Full design in BACKLOG.md.
