Session 2 opened. Role: Runner Engineer. Objective: build pkg/runnerlib shared library. All constitutional documents absorbed.
Session 3 opened. Role: Controller Engineer. Objective: RBACPolicy CRD types, validation logic, RBACPolicyReconciler, controller-runtime manager skeleton. Open finding on community tier limit acknowledged — non-blocking this session.
Session 3 closed. All 13 steps complete. 12 unit tests + 5 integration tests green. go vet clean. go build clean. Commit c205ea5.

# ONT Platform Progress
## Platform State
Status: Foundation in progress. Shared library complete. ont-security RBACPolicy reconciler complete.
Current Phase: Phase 1 — Development
Last Session: Session 3 — Controller Engineer, ont-security RBACPolicy
Next Session: Session 4 — Controller Engineer, ont-security RBACProfile types, EPG reconciler skeleton, IdentityBinding types

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
- [Session 3] RBACPolicy CRD types — RBACPolicySpec, RBACPolicyStatus, EnforcementMode, SubjectScope, condition/reason constants
- [Session 3] Manual DeepCopy implementations (zz_generated.deepcopy.go), SetCondition/FindCondition helpers
- [Session 3] ValidateRBACPolicySpec — all-failures collection, 4 checks (scope, mode, cluster format, permset ref)
- [Session 3] RBACPolicyReconciler — fetch, defer status patch, ObservedGeneration, validate, set conditions, emit events
- [Session 3] Controller-runtime manager skeleton (cmd/ont-security/main.go) — flags, scheme, leader election, health probes
- [Session 3] CRD YAML (config/crd/security.ontai.dev_rbacpolicies.yaml) — handwritten, envtest-compatible
- [Session 3] 12 unit tests passing (test/unit/controller/rbacpolicy_validation_test.go)
- [Session 3] 5 integration tests passing via envtest (test/integration/controller/rbacpolicy_controller_test.go)
- [Session 3] go vet clean, go build clean

## Open Findings
- [Session 1] Lab directory is named `ont-lab/` in the filesystem but `ontai-lab/` in
  CLAUDE.md Section 9. Naming inconsistency. No action taken — constitutional
  amendment required from Platform Governor before renaming.
- [Session 1] Operator repositories (`ont-runner/`, `ont-security/`, `ont-platform/`,
  `ont-infra/`) reside inside `ontai/` as subdirectories, not as peer repositories
  alongside `ontai/`. Proceeding with current layout.
- [Session 2] Community tier cluster limit conflict: CLAUDE.md §8 says max 3 clusters;
  ont-runner-schema.md §11 and ont-runner-design.md §7.5 say max 5 clusters.
  Relevant to internal/license implementation (Session 5+).
  Requires Platform Governor resolution before that session begins.
- [Session 3] ont-security/CLAUDE.md contains errors: domain listed as "platform.ontai.dev"
  (should be "security.ontai.dev"), operator name misspelled as "ont-secuirty". All
  code correctly uses "security.ontai.dev". Constitutional amendment from Platform
  Governor required to correct the CLAUDE.md.
- [Session 3] CRD YAML is handwritten. controller-gen is not yet wired. When controller-gen
  is wired in a future session, the handwritten CRD must be replaced with the generated
  output and the two must be verified equivalent.
- [Session 3] DeepCopy implementations are manually written in zz_generated.deepcopy.go.
  Same note as above — replace with controller-gen output when wired.
- [Session 3] Integration tests require KUBEBUILDER_ASSETS env var. envtest binaries at
  /tmp/envtest-bins/k8s/1.35.0-linux-amd64 (obtained via setup-envtest). Not persisted
  across machine reboots — run setup-envtest again if binaries are absent.

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

## Session 3 Exit State

**Commit:** c205ea5 (ont-security, branch session/1-governor-init)

**Files created in api/v1alpha1/:**
- groupversion_info.go — GroupVersion, SchemeBuilder, AddToScheme
- rbacpolicy_types.go — EnforcementMode, SubjectScope, condition/reason constants, RBACPolicySpec, RBACPolicyStatus, RBACPolicy, RBACPolicyList
- zz_generated.deepcopy.go — manual DeepCopy implementations for all types
- conditions.go — SetCondition, FindCondition helpers

**Files created in internal/controller/:**
- rbacpolicy_validation.go — ValidationCheckName constants, PolicyValidationResult, ValidateRBACPolicySpec (4 checks, all-failures collection)
- rbacpolicy_controller.go — RBACPolicyReconciler (fetch, defer status patch, ObservedGeneration, validate, set conditions, emit events), SetupWithManager with GenerationChangedPredicate

**Files created in cmd/ont-security/:**
- main.go — flag parsing, scheme setup, RBACPolicyReconciler registration, health/readiness probes, leader election (lease: ont-security-leader, namespace: security-system)

**Files created in config/crd/:**
- security.ontai.dev_rbacpolicies.yaml — handwritten CRD YAML, envtest-compatible

**Test files:**
- test/unit/controller/rbacpolicy_validation_test.go — 12 tests, all passing
- test/integration/controller/rbacpolicy_controller_test.go — 5 tests via envtest, all passing

**go mod tidy:** Clean. go.sum generated.

**Lint:** go vet clean.

**TODOs in code (non-blocking, carry to future sessions):**
- rbacpolicy_controller.go: TODO(session-4) comment for PermissionSet existence check at
  policy.Spec.MaximumPermissionSetRef. To be added after PermissionSet types are defined.
- main.go: TODO comments for future reconcilers (RBACProfile, EPG, IdentityBinding) and
  webhook server registration.

**Integration test note:**
Tests require KUBEBUILDER_ASSETS=/tmp/envtest-bins/k8s/1.35.0-linux-amd64.
Run: setup-envtest use --bin-dir /tmp/envtest-bins to restore if absent.
