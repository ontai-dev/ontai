Session 2 opened. Role: Runner Engineer. Objective: build pkg/runnerlib shared library. All constitutional documents absorbed.

# ONT Platform Progress
## Platform State
Status: Foundation in progress. Shared library types and constants complete. Generator stubs operational. Unit tests green.
Current Phase: Phase 1 — Development
Last Session: Session 2 — Runner Engineer, shared library
Next Session: Session 3 — Runner Engineer, binary entry points and mode routing

## Completed Gates
- [Session 1] Constitutional documents committed to ontai root
- [Session 1] All repository directories initialized with git and initial structure
- [Session 1] Tracking documents created (PROGRESS.md, BACKLOG.md, GIT_TRACKING.md)
- [Session 1] Prompt injection in ont-runner-schema.md detected and flagged; removed by Platform Governor
- [Session 2] pkg/runnerlib shared library types defined — RunnerConfigSpec, CapabilityManifest, OperationResultSpec, JobSpecBuilder
- [Session 2] All 18 named capability constants defined and verified unique
- [Session 2] Generator implementations: GenerateFromTalosCluster, GenerateFromPackBuild
- [Session 2] JobSpecBuilder concrete implementation with invariant enforcement (value semantics, ReadOnly enforced, defaults applied)
- [Session 2] All 31 unit tests passing, zero lint warnings (go vet clean)

## Open Findings
- [Session 1] Lab directory is named `ont-lab/` in the filesystem but `ontai-lab/` in
  CLAUDE.md Section 9. Naming inconsistency. No action taken — constitutional
  amendment required from Platform Governor before renaming.
- [Session 1] Operator repositories (`ont-runner/`, `ont-security/`, `ont-platform/`,
  `ont-infra/`) reside inside `ontai/` as subdirectories, not as peer repositories
  alongside `ontai/`. Proceeding with current layout.
- [Session 2] Community tier cluster limit conflict: CLAUDE.md §8 and ont-runner/CLAUDE.md
  CR-INV-008 state max 3 clusters; ont-runner-schema.md §11 and ont-runner-design.md §7.5
  state max 5 clusters. Relevant to internal/license implementation (Session 5+).
  Requires Platform Governor resolution before that session begins.

## Session 1 Exit State
All five repositories initialized. Constitutional documents in ontai root committed
on branch session/1-governor-init. All component repositories initialized with
skeleton structure on branch session/1-governor-init.

Commit hashes:
- ont-runner:   d176ed9
- ont-security: 194934c
- ont-platform: a38188f
- ont-infra:    86807d4
- ontai:        d54ac90

## Session 2 Capability Reference

All 18 named capabilities from ont-runner-schema.md Section 6.
Mode is always executor unless noted. Triggering CRD from operator schemas.

| Constant                    | String Value        | Owner       | Triggering CRD          | Description                                      |
|-----------------------------|---------------------|-------------|-------------------------|--------------------------------------------------|
| CapabilityBootstrap         | bootstrap           | ont-platform| TalosCluster            | Full cluster bootstrap from seed nodes           |
| CapabilityTalosUpgrade      | talos-upgrade       | ont-platform| TalosUpgrade            | Rolling Talos OS version upgrade                 |
| CapabilityKubeUpgrade       | kube-upgrade        | ont-platform| TalosKubeUpgrade        | Kubernetes version upgrade                       |
| CapabilityStackUpgrade      | stack-upgrade       | ont-platform| TalosStackUpgrade       | Coordinated Talos OS + Kubernetes upgrade        |
| CapabilityNodePatch         | node-patch          | ont-platform| TalosNodePatch          | Machine config patch to nodes                    |
| CapabilityNodeScaleUp       | node-scale-up       | ont-platform| TalosNodeScaleUp        | Add nodes to existing cluster                    |
| CapabilityNodeDecommission  | node-decommission   | ont-platform| TalosNodeDecommission   | Cordon, drain, remove node                       |
| CapabilityNodeReboot        | node-reboot         | ont-platform| TalosReboot             | Reboot nodes                                     |
| CapabilityEtcdBackup        | etcd-backup         | ont-platform| TalosBackup             | etcd snapshot + config export to S3              |
| CapabilityEtcdMaintenance   | etcd-maintenance    | ont-platform| TalosEtcdMaintenance    | etcd defrag and optional snapshot                |
| CapabilityEtcdRestore       | etcd-restore        | ont-platform| TalosRecovery           | Disaster recovery from S3 snapshot               |
| CapabilityPKIRotate         | pki-rotate          | ont-platform| TalosPKIRotation        | PKI certificate rotation                         |
| CapabilityCredentialRotate  | credential-rotate   | ont-platform| TalosCredentialRotation | Service account key rotation                     |
| CapabilityHardeningApply    | hardening-apply     | ont-platform| TalosHardeningApply     | Apply TalosHardeningProfile                      |
| CapabilityClusterReset      | cluster-reset       | ont-platform| TalosClusterReset       | Destructive factory reset with human gate        |
| CapabilityPackCompile       | pack-compile        | ont-infra   | PackBuild               | Compile PackBuild into ClusterPack (executor Job)|
| CapabilityPackDeploy        | pack-deploy         | ont-infra   | PackExecution           | Apply ClusterPack to target cluster              |
| CapabilityRBACProvision     | rbac-provision      | ont-security| (agent-initiated)       | Provision RBAC artifacts from snapshot           |

Notes:
- pack-compile runs as a Kueue Job (executor mode) triggered by ont-infra — distinct
  from the runner compile mode binary subcommand. No confusion with compile mode.
- cluster-reset is multi-step and uses the PVC protocol (ont-runner-design.md §5.6).
- bootstrap is multi-step and uses the PVC protocol.
- stack-upgrade is multi-step and uses the PVC protocol.

## Session 2 Exit State

**Commit:** 56e1582 (ont-runner, branch session/1-governor-init)

**Files created in pkg/runnerlib/:**
- doc.go — package-level godoc
- constants.go — 18 named capability constants
- runnerconfig.go — RunnerConfigSpec, PhaseConfig, OperationalHistoryEntry, SecretRef, RunnerConfigStatus, LicenseStatus
- capability.go — CapabilityManifest, CapabilityEntry, CapabilityMode, ParameterDef
- operationresult.go — OperationResultSpec, ResultStatus, ArtifactRef, FailureReason, FailureCategory, StepResult
- jobspec.go — JobSpecBuilder interface, jobSpecBuilder implementation, NewJobSpecBuilder, JobSpec, SecretVolume
- generators.go — TalosClusterSpec, PackBuildSpec, HelmSource, KustomizeSource, RawManifestSource, GenerateFromTalosCluster, GenerateFromPackBuild

**Test files created in test/unit/runnerlib/:**
- runnerconfig_test.go — 4 tests
- capability_test.go — 4 tests
- operationresult_test.go — 5 tests
- jobspec_test.go — 6 tests (including subtests)
- generators_test.go — 6 tests
- constants_test.go — 5 tests
- Total: 31 tests, 31 passing

**go mod tidy:** Clean. go.sum generated.

**Lint:** go vet clean. staticcheck and golangci-lint not installed.

**TODOs in code (non-blocking, carry to future sessions):**
- generators.go: ClusterEndpoint used as cluster identity pending formal name field
  on TalosCluster CRD. Flagged with TODO comment.
- generators.go: RunnerImage left empty by generators — callers set this.
  Documented in godoc.

**Ambiguity flagged (non-blocking this session):**
- Community tier cluster limit: CLAUDE.md/ont-runner CLAUDE.md say 3, schema/design say 5.
  Needs Platform Governor resolution before internal/license implementation.
