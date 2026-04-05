# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 0. Anti-Patterns (FORBIDDEN)
- Adding Co-Authored-By trailers to commits
- Pushing the ontai root repository to a git remote — ontai root is intentionally not a git remote repository; do not attempt to push it
- Creating or assuming a namespace outside the canonical model (seam-system, ont-system, seam-tenant-{cluster-name}) without a Governor directive

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | 68d11f3     | WS1: SigningLoop signs PackInstance+PermissionSnapshot CRs with Ed25519 (SIGNING_PRIVATE_KEY_PATH gate, management cluster only, INV-026); WS2: local PermissionService gRPC (SnapshotStore + LocalService + hand-written service descriptor, PERMISSION_SERVICE_ADDR, all clusters); WS3: SnapshotPullLoop — target cluster pulls PermissionSnapshot from management, verifies Ed25519 (SIGNING_PUBLIC_KEY_PATH + MGMT_KUBECONFIG_PATH gates), calls SnapshotStore.Update; DegradedSecurityState on failure; bootstrap window mode (INV-020); session/25: CapabilityRBACProvision — Ed25519 signature verification (INV-026), bootstrap window bypass (INV-020), SigningPublicKey field added to ExecuteClients; session/governor (WS1-Compiler): Compiler subcommand model corrected — CR compiler (bootstrap/launch/enable/packbuild/domain) — F-P2 closed; session/governor (F-P4): WS1 three-image Dockerfile scaffolding (Dockerfile.compiler/execute/agent + docker-build Makefile target); WS2 RunnerConfig self-operation fields (MaintenanceTargetNodes/OperatorLeaderNode/SelfOperation + JobSpec.NodeExclusions + ResolveNodeExclusionsFromRunnerConfig + 5 new tests); WS3 compiler real implementations (platform+wrapper+seam-core local replace directives, compileBootstrap/compileLaunch/compileEnable produce TalosCluster CR YAML, compilePackBuild produces ClusterPack CR YAML); 7 suites green (F-P4 closed); session/29 WS3: compiler maintenance subcommand — resolves kubeconfig (flag→KUBECONFIG env→~/.kube/config), reads platform-leader Lease → pod → NodeName, validates S3 Secret for etcd-backup ops, validates target nodes, produces MaintenanceBundle CR YAML; 7 suites green; session/31 (F-P6): WS1: internal/catalog/ embedded FS with Go embed (entries/ YAML templates for Cilium/CNPG/Kueue/cert-manager/local-path-provisioner), CatalogEntry/RenderParams/ComponentDescriptor types, catalog.All()/Lookup()/AvailableNames()/Render()/DescriptorScaffold(); 14 unit tests in test/unit/catalog/; 8 suites green — 5eaceed; WS2: compiler component subcommand wired into main.go (catalog mode, descriptor mode, discover mode), compile_component.go + compile_component_test.go; 15 new tests; 9 suites green — 6000606. F-P6 closed. session/32: Compiler bootstrap/launch/enable real implementations. WS1 (d6bac86): compileBootstrap uses talos machinery (generate.NewInput, secrets.NewBundle, node-per-Secret, seam-mc-{cluster}-{hostname} naming, TalosCluster CR YAML, bootstrap-sequence.yaml, BootstrapSequence with json+yaml tags); 10 tests. WS2 (51264ca): compileLaunchBundle uses go embed from all 5 CRD repos (platform, guardian, wrapper, seam-core, conductor) — guardian added to go.mod replace block; crds.yaml bundle sorted+deterministic; 8 tests. WS3 (3745987): compileEnableBundle produces crds.yaml+operators.yaml+rbac.yaml+leaderelection.yaml+rbacprofiles.yaml; Conductor carries CONDUCTOR_ROLE=management (§15); all 5 operators with correct namespaces (conductor→ont-system, others→seam-system); RBACProfile CRs with review-required annotation; 11 tests. 9 suites green. session/governor (RunnerConfig Execution Model §17): WS1 (b62be77): RunnerConfigStep, StepPhase, ConfigMapRef, RunnerConfigStepResult added to runnerlib; Steps to RunnerConfigSpec, StepResults to RunnerConfigStatus; CRD YAML updated. WS2 (68d11f3): RunExecute replaced with step sequencer — StepExecutor + StepStatusWriter interfaces, NoopStepStatusWriter, capabilityStepExecutor in main.go; 9 kernel tests (single-step, multi-step, halt-on-failure, partial completion, error propagation). 9 suites green. | — |
| guardian     | 68ebe07     | WS1: SealedCausalChain spec.lineage added to RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet; CRDs regenerated; seam-core dependency wired; WS2: LineageSynced=False/LineageControllerAbsent initialization in all 5 reconcilers; lineage_conditions.go added; WS3 (session/24): lineage_immutability.go + lineage_handler.go + RegisterLineage — rejects spec.lineage UPDATE on all 5 root-declaration kinds; 16 new unit tests green | SealedCausalChain immutability webhook — CLOSED session/24 |
| platform     | 2c093c8     | TalosCluster + SeamInfrastructureCluster/Machine CRD types, all three reconcilers (TalosCluster, SIC, SIM), SIC/SIM CRDs with lineage + controller-gen clean, SIM implements 6-step machineconfig delivery via TalosMachineConfigApplier (only file with talos goclient, CP-INV-001 clean), unit tests green, go build clean; session/governor: all 8 day-2 CRD types (EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile, UpgradePolicy, NodeOperation, ClusterMaintenance) with spec.lineage; all 8 day-2 reconcilers implemented with CapabilityUnavailable/PendingApproval gates; wired into main.go; 12 new unit tests green (F-P1 closed, F-P3 closed); session/29 WS1: resolveOperatorLeaderNode (platform-leader Lease → pod → NodeName) + jobSpecWithExclusions (NotIn NodeAffinity) wired into all 6 Job-submitting day-2 reconcilers; EtcdMaintenance S3 resolution hierarchy (EtcdBackupS3SecretRef spec field + seam-etcd-backup-config default + EtcdBackupDestinationAbsent condition); 6 new unit tests + 1 updated; all 17 tests green; session/29 WS2: MaintenanceBundle CRD (operation enum drain/upgrade/etcd-backup/machineconfig-rotation, maintenanceTargetNodes, operatorLeaderNode, s3ConfigSecretRef, spec.lineage); stub reconciler (F-P5); CRD YAML generated; wired into main.go; session/30 WS1: MaintenanceBundleReconciler full implementation — reads pre-encoded scheduling context, submits Job via jobSpecWithExclusions, transitions Pending→Ready/Degraded; JobName+OperationResult status fields; CRD YAML regenerated; 5 new tests; session/30 WS2: EnsureConductorDeploymentOnTargetCluster in TalosClusterReconciler — creates Conductor agent Deployment in ont-system on target cluster before marking Ready; CAPI kubeconfig Secret lookup; CONDUCTOR_ROLE=tenant env stamp; BuildConductorAgentDeployment; 3 new tests; all tests green | — |
| wrapper      | 6ab6eed     | WS1: ClusterPack/PackExecution/PackInstance CRDs + deepcopy + 3 CRD YAMLs; WS2: ClusterPackReconciler (immutability enforcement, signature transition, SignaturePending requeue), PackExecutionReconciler (4-gate check, Kueue Job submission, OperationResult read); WS3: PackInstanceReconciler (PackReceipt drift/security, DependencyBlock); spec.lineage (SealedCausalChain) embedded in all 3 root-declaration specs, CRD YAMLs regenerated; 17 unit tests green | Governor scheduling for remaining deferred items |
| seam-core    | ba71b2f     | LineageController complete (be0aaa1); session/24: WS2+WS3 — ILI immutability webhook (spec.rootBinding UPDATE rejected), controller-authorship gate (CREATE/UPDATE allowed only from lineage-controller SA), both wired into cmd/seam-core/main.go; 29 new unit tests green | Governor scheduling for remaining deferred items |

---

## 2. Open Findings

| ID    | Description                                                                    | Blocking?                              |
|-------|--------------------------------------------------------------------------------|----------------------------------------|
| F-S1  | Repo subdirectories not yet created in component repos                         | No                                     |
| F-S3  | ~~CRD YAML and DeepCopy are handwritten; controller-gen not wired~~ CLOSED Session 9 | Closed |
| F-S3B | KUBEBUILDER_ASSETS must be set manually for envtest runs                       | No (infra note)                        |
| F-S3C | ~~PermissionRule.Verbs requires typed Verb string~~ CLOSED Session 10 — Verb type added, CRD enum restored | Closed |
| F-6D  | ~~CapabilityRBACProvision executor-mode confirmed; implementation pending~~ CLOSED session/25 — conductor 2e2afa9 | Closed |
| F-P1  | ~~Day-2 CRD types and reconcilers absent in platform~~ CLOSED session/governor — platform f7f797b. All 8 day-2 types (EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile, UpgradePolicy, NodeOperation, ClusterMaintenance) defined with spec.lineage; all 8 reconcilers implemented; wired into main.go; 12 unit tests green. | Closed |
| F-P2  | ~~Compiler subcommand model corrected~~ CLOSED session/governor (WS2) — conductor 2efc758. Compiler is a CR compiler: reads human-authored spec files and emits Kubernetes CR YAML only. Correct subcommands: `bootstrap`, `launch`, `enable` (all produce TalosCluster CR YAML), `packbuild` (produces ClusterPack CR YAML), `domain` (reserved). SOPS, Helm, and Kustomize are execution-mode concerns owned by Conductor Execute Mode — not Compiler concerns. Stubs return honest not-implemented errors; actual blockers are CR type integration from platform and wrapper libraries. | Closed |
| F-P3  | ~~Non-CAPI cluster lifecycle scope unverified~~ CLOSED session/governor — spec.capi.enabled=false is exclusively for management cluster bootstrap (thin Job submitter path). Target clusters always use CAPI. Day-2 node lifecycle (join, expansion, decommission) is handled by NodeOperation and UpgradePolicy CRDs delivered in F-P1. No gap found; no code changes required. | Closed |
| F-P5  | ~~MaintenanceBundle CRD definition absent~~ CLOSED session/29 WS2 — platform b00fcd5. CRD defined (platform.ontai.dev/v1alpha1), all spec fields (operation enum, maintenanceTargetNodes, operatorLeaderNode, s3ConfigSecretRef, spec.lineage), status conditions (ConditionTypeMaintenanceBundlePending initialized as stub, ConditionTypeLineageSynced), controller-gen CRD YAML generated, stub reconciler wired into main.go. Full RunnerConfig creation and Job submission remain deferred. compiler maintenance (conductor 2091ce0) produces MaintenanceBundle CR YAML with pre-resolved scheduling context. | Closed |
| F-P6  | ~~compiler component real implementation~~ CLOSED session/31 — conductor 6000606. WS1: internal/catalog/ embedded FS, 5 RBACProfile templates, 14 unit tests. WS2: compiler component subcommand (catalog/descriptor/discover modes), wired into main.go, 15 unit tests. 9 suites green. | Closed |
| F-P7  | Update all existing day-2 reconcilers in platform to use the step list model rather than single-capability RunnerConfig. Eight reconcilers affected: EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile, UpgradePolicy, NodeOperation, ClusterMaintenance. Requires Platform Controller Engineer session after Conductor step sequencer implementation (session/32 WS2). conductor-schema.md §17. | No (Conductor implementation must land first) |

---

## 3. Role Reading Map

| Role                    | Required Documents (beyond CONTEXT.md)                                                       |
|-------------------------|----------------------------------------------------------------------------------------------|
| Governor                | PROGRESS.md, GIT_TRACKING.md, BACKLOG.md                                                     |
| Domain Architect        | *-schema.md for target domain                                                                |
| Schema Engineer         | Target *-schema.md + target component *-design.md + existing CRD YAML in that repo          |
| Controller Engineer     | guardian-schema.md + guardian/guardian-design.md + domain-core-schema.md + seam-core-schema.md (Guardian work) |
| Controller Engineer     | platform-schema.md + platform/platform-design.md + domain-core-schema.md + seam-core-schema.md (Platform work) |
| Controller Engineer     | wrapper-schema.md + wrapper/wrapper-design.md + domain-core-schema.md + seam-core-schema.md (Wrapper work)   |
| Conductor Engineer      | conductor-schema.md + conductor/conductor-design.md + all operator *-schema.md + domain-core-schema.md + seam-core-schema.md |
| Platform Engineer       | Target component *-schema.md + Dockerfile context for that component                        |
| Test Engineer           | Target *-schema.md + target component *-design.md                                           |
| Lab Operator            | ont-lab/ runbooks + CLAUDE.md §9                                                             |
| Release Engineer        | GIT_TRACKING.md, BACKLOG.md                                                                  |
| Incident Analyst        | PROGRESS.md + target component *-schema.md                                                   |

---

## 4. Namespace Model (Locked Governor Decision — 2026-04-05)

Three namespaces exist in the Seam platform. No operator may create or assume any other namespace without a Governor directive.

| Namespace | Purpose | Who owns it |
|-----------|---------|-------------|
| `seam-system` | Single operator namespace on the management cluster. All Seam operator managers (guardian, platform, wrapper, seam-core) run here. All leader election leases are held here. | All operators |
| `ont-system` | Conductor agent namespace. Exists on every cluster (management and target). Conductor agent Deployment runs here. Conductor execute-mode Jobs submitted by Wrapper run here on the management cluster. SnapshotStore, signing loop, and pull loop operate from this namespace. | Conductor |
| `seam-tenant-{cluster-name}` | One per managed cluster. ClusterPack, PackExecution, PackInstance, and all tenant-scoped objects live here. Created exclusively by the Platform operator (CP-INV-004). | Platform (creates); operators (read) |

Inventions such as `security-system`, `platform-system`, `infra-system`, `guardian-system`, or any unnamed variant are forbidden. They have been removed. This model is locked.

---

## 5. Next Session

**Role:** Governor
**Purpose:** Review session/32 completion, triage open findings, schedule next work item. Session/32 workstreams closed:
- WS1 (conductor d6bac86): compiler bootstrap real implementation — 10 tests.
- WS2 (conductor 51264ca): compiler launch real implementation — 8 tests.
- WS3 (conductor 3745987): compiler enable real implementation — 11 tests. 9 suites green.

Compiler bootstrap/launch/enable are fully implemented. All compiler subcommands produce real output.

**Recommended next work:** Platform Controller Engineer session for F-P7 — update all eight platform day-2 reconcilers (EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile, UpgradePolicy, NodeOperation, ClusterMaintenance) to use the step list model rather than single-capability RunnerConfig. The Conductor step sequencer is now in place (68d11f3). Also queued: (a) domain-core scaffold — Schema Engineer session to define DomainLineageIndex CRD; (b) compiler enable integration-testing against actual lab cluster (Guardian bootstrap → admission webhook operational, closes INV-020).

---
*Maintained by the Governor role. Refresh after every Governor session.*
*Section 4 (Namespace Model) locked 2026-04-05 by Governor directive.*
