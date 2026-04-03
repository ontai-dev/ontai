# Seam Platform Backlog
## Phase 1 — Development

### conductor (formerly ont-runner)
- [x] Shared library: RunnerConfig schema types (pkg/runnerlib)
- [x] Shared library: CapabilityManifest and CapabilityEntry types
- [x] Shared library: OperationResult types
- [x] Shared library: GenerateFromTalosCluster function
- [x] Shared library: GenerateFromPackBuild function
- [x] Shared library: JobSpecBuilder interface
- [x] Shared library: full unit test coverage
- [ ] Binary entry points: compile, execute, agent mode routing
- [ ] Capability engine: registry, resolver, dispatcher
- [ ] All named capabilities implemented (see conductor-schema.md capability table)
- [ ] Agent mode: leader election, capability publisher, control loops
- [ ] Compile mode: TalosCluster validation pipeline
- [ ] Compile mode: PackBuild compilation pipeline

### guardian (formerly ont-security)
- [x] RBACPolicy reconciler (Session 3)
- [x] RBACProfile reconciler with provisioned gate (Session 4, CS-INV-005)
- [x] EPG computation engine — stub only (Session 4); full computation deferred to Session 5
- [x] EPG computation engine — full implementation (Session 5)
- [x] PermissionSnapshot generation (Session 5)
- [x] PermissionSnapshotReceipt watch and drift-check dispatch (Session 6)
- [x] reconcileDrift implemented with transition events (Session 6)
- [x] Admission webhook server skeleton (Session 7, CS-INV-001, CS-INV-004)
- [ ] Bootstrap RBAC window — close TODO(session-8) in internal/webhook/decision.go (INV-020, CS-INV-004)
- [ ] Schema Engineer session: wire controller-gen, validate CRD YAML equivalence (REQUIRES GOVERNOR SCHEDULING)
- ~~[ ] Governor resolution: CapabilityPackCompile — annotate constant with Option B semantics (Finding 6-A)~~ REMOVED — dismissed design. Option B (validation-only Conductor Job) is withdrawn. pack-compile is a Compiler compile mode capability. No cluster Job. Finding 6-A closed 2026-04-01.
- [ ] Governor clarification: CapabilityRBACProvision — executor-mode capability (Finding 6-D, Governor decided)
- [ ] PermissionSet reconciler: ProfileReferenceCount maintenance (no owner currently)
- [ ] PermissionService gRPC server (4 operations)
- [ ] CNPG two-phase boot sequence (CS-INV-003)
- [x] IdentityBinding reconciler — stub only (Session 4); full EPG trigger wiring deferred to Session 5
- [x] PermissionSet types and validation (Session 4)
- [ ] PermissionSet reconciler (owns ProfileReferenceCount maintenance)
- [ ] Third-party RBAC intake process
- [ ] controller-gen wiring (replaces handwritten CRD YAML and zz_generated.deepcopy.go)
- [ ] IdentityProvider reconciler — PREREQUISITE: IdentityProvider must be implemented before
      any Controller Engineer session implementing identity trust methods in IdentityBinding.

### platform (formerly ont-platform)
- [ ] TalosCluster reconciler (bootstrap and import modes — management cluster direct path)
- [ ] TalosCluster reconciler — CAPI object creation path (capi.enabled=true)
- [ ] SeamInfrastructureClusterReconciler — CAPI InfrastructureCluster contract
- [ ] SeamInfrastructureMachineReconciler — machineconfig delivery via talos goclient on port 50000 with providerID and ready status
- [ ] TalosControlPlane CRD types and reconciler
- [ ] TalosWorkerConfig CRD types and reconciler
- [ ] Cilium deployment trigger — ClusterAssignment bootstrapFlag PackExecution wiring on CAPI Cluster phase=Running
- [ ] RunnerConfig generation from TalosCluster spec (operational Job CRDs only; not CAPI lifecycle)
- [ ] Tenant namespace lifecycle management
- [ ] PlatformTenant reconciler
- [ ] ClusterAssignment reconciler with all gate conditions
- [ ] QueueProfile reconciler
- ~~[ ] LicenseKey reconciler~~ REMOVED — Seam has no licensing tier.
- ~~[ ] TalosBackup reconciler~~ REMOVED — absorbed into EtcdMaintenance.
- ~~[ ] TalosEtcdMaintenance reconciler~~ REMOVED — absorbed into EtcdMaintenance.
- ~~[ ] TalosRecovery reconciler~~ REMOVED — absorbed into EtcdMaintenance.
- ~~[ ] TalosNodePatch reconciler~~ REMOVED — absorbed into NodeMaintenance.
- ~~[ ] TalosHardeningApply reconciler~~ REMOVED — absorbed into NodeMaintenance.
- ~~[ ] TalosHardeningProfile reconciler~~ REMOVED — absorbed into HardeningProfile.
- ~~[ ] TalosCredentialRotation reconciler~~ REMOVED — absorbed into NodeMaintenance.
- ~~[ ] TalosPKIRotation reconciler~~ REMOVED — absorbed into PKIRotation.
- ~~[ ] TalosNoMaintenance reconciler~~ REMOVED — absorbed into ClusterMaintenance.
- ~~[ ] TalosClusterReset reconciler~~ REMOVED — absorbed into ClusterReset.
- ~~[ ] TalosUpgrade reconciler~~ REMOVED — absorbed into UpgradePolicy.
- ~~[ ] TalosKubeUpgrade reconciler~~ REMOVED — absorbed into UpgradePolicy.
- ~~[ ] TalosStackUpgrade reconciler~~ REMOVED — absorbed into UpgradePolicy.
- ~~[ ] TalosNodeScaleUp reconciler~~ REMOVED — absorbed into NodeOperation.
- ~~[ ] TalosNodeDecommission reconciler~~ REMOVED — absorbed into NodeOperation.
- ~~[ ] TalosReboot reconciler~~ REMOVED — absorbed into NodeOperation.
- [ ] EtcdMaintenance reconciler (absorbs: TalosBackup, TalosEtcdMaintenance, TalosRecovery)
- [ ] NodeMaintenance reconciler (absorbs: TalosNodePatch, TalosHardeningApply, TalosCredentialRotation)
- [ ] PKIRotation reconciler (absorbs: TalosPKIRotation)
- [ ] ClusterReset reconciler with human gate (absorbs: TalosClusterReset)
- [ ] HardeningProfile CR support (absorbs: TalosHardeningProfile)
- [ ] UpgradePolicy reconciler with dual-path routing (absorbs: TalosUpgrade, TalosKubeUpgrade, TalosStackUpgrade)
- [ ] NodeOperation reconciler with dual-path routing (absorbs: TalosNodeScaleUp, TalosNodeDecommission, TalosReboot)
- [ ] ClusterMaintenance reconciler with CAPI pause integration (absorbs: TalosNoMaintenance)

### wrapper (formerly ont-infra)
- ~~[ ] PackBuild reconciler~~ REMOVED — dismissed design. PackBuild is a local spec file on the workstation, not a cluster CRD. No PackBuildReconciler or PackBuildController will ever be implemented. Replaced by Compiler compile mode.
- ~~[ ] RunnerConfig generation from PackBuild spec~~ REMOVED — dismissed design. PackBuild is not a cluster CRD and triggers no RunnerConfig. pack-compile is a Compiler compile mode invocation, not a Kueue Job.
- [ ] ClusterPack reconciler
- [ ] PackExecution reconciler with execution gatekeeper
- [ ] PackInstance reconciler with drift integration

### seam-core (new)
- [ ] Repository initialization
- [ ] Schema controller implementation
- [ ] InfrastructurePolicy CRD type definition
- [ ] InfrastructureProfile CRD type definition
- [ ] RunnerConfig CRD ownership transfer from conductor shared library to seam-core —
      **BLOCKED: requires a dedicated Governor-scheduled Controller Engineer session.
      This is not a documentation gap. It has implementation implications across
      conductor, platform, and wrapper and must not be acted on without explicit
      Governor scheduling.**

### screen (formerly ont-virt)
- [ ] Repository creation
- [ ] VirtCluster CRD
- [ ] CAPI infrastructure provider for QEMU/KVM via libvirt
- [ ] KubeVirt ClusterPack integration

### vortex (formerly ont-portal)
- [ ] Repository creation
- [ ] PortalPolicy CRD
- [ ] React portal implementation
- [ ] Cluster lifecycle UI
- [ ] Domain topology visualization

## Phase 2 — Platform Engineer
- [ ] Dockerfiles for all components
- [ ] GitHub Actions CI workflows
- [ ] OCI push pipeline configuration

## Phase 3 — Integration and e2e Tests
- [ ] guardian full integration test suite
- [ ] conductor capability integration tests
- [ ] platform e2e bootstrap gate on ccs-test
- [ ] wrapper pack compile and deploy e2e gate

## Phase 4 — Release
- [ ] Release Engineer session pending Phase 3 green gate
