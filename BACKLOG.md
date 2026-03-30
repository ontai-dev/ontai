# ONT Platform Backlog
## Phase 1 — Development

### ont-runner
- [ ] Shared library: RunnerConfig schema types (pkg/runnerlib)
- [ ] Shared library: CapabilityManifest and CapabilityEntry types
- [ ] Shared library: OperationResult types
- [ ] Shared library: GenerateFromTalosCluster function
- [ ] Shared library: GenerateFromPackBuild function
- [ ] Shared library: JobSpecBuilder interface
- [ ] Shared library: full unit test coverage
- [ ] Binary entry points: compile, execute, agent mode routing
- [ ] License layer: JWT validation, community token constant, cluster count enforcer
- [ ] Capability engine: registry, resolver, dispatcher
- [ ] All named capabilities implemented (see ont-runner-schema.md capability table)
- [ ] Agent mode: leader election, capability publisher, control loops
- [ ] Compile mode: TalosCluster validation pipeline
- [ ] Compile mode: PackBuild compilation pipeline

### ont-security
- [x] RBACPolicy reconciler (Session 3)
- [x] RBACProfile reconciler with provisioned gate (Session 4, CS-INV-005)
- [x] EPG computation engine — stub only (Session 4); full computation deferred to Session 5
- [x] EPG computation engine — full implementation (Session 5)
- [x] PermissionSnapshot generation (Session 5)
- [x] PermissionSnapshotReceipt watch and drift-check dispatch (Session 6)
- [x] reconcileDrift implemented with transition events (Session 6)
- [ ] Admission webhook server — Session 7 (CS-INV-001, CS-INV-004)
- [ ] Session 7: admission webhook server skeleton in ont-security
- [ ] Schema Engineer session: wire controller-gen, validate CRD YAML equivalence (REQUIRES GOVERNOR SCHEDULING)
- [ ] Governor resolution: CapabilityPackCompile — annotate constant with Option B semantics (Finding 6-A)
- [ ] Governor clarification: CapabilityRBACProvision — executor-mode capability (Finding 6-D, Governor decided)
- [ ] PermissionSet reconciler: ProfileReferenceCount maintenance (no owner currently)
- [ ] PermissionService gRPC server (4 operations)
- [ ] CNPG two-phase boot sequence (CS-INV-003)
- [x] IdentityBinding reconciler — stub only (Session 4); full EPG trigger wiring deferred to Session 5
- [x] PermissionSet types and validation (Session 4)
- [ ] PermissionSet reconciler (owns ProfileReferenceCount maintenance)
- [ ] Third-party RBAC intake process
- [ ] controller-gen wiring (replaces handwritten CRD YAML and zz_generated.deepcopy.go)

### ont-platform
- [ ] TalosCluster reconciler (bootstrap and import modes — management cluster direct path)
- [ ] TalosCluster reconciler — CAPI object creation path (capi.enabled=true)
- [ ] ONTInfrastructureClusterReconciler — CAPI InfrastructureCluster contract
- [ ] ONTInfrastructureMachineReconciler — machineconfig delivery via talos goclient on port 50000 with providerID and ready status
- [ ] Cilium deployment trigger — ClusterAssignment bootstrapFlag PackExecution wiring on CAPI Cluster phase=Running
- [ ] TalosNoMaintenanceReconciler — CAPI pause annotation integration
- [ ] TalosClusterResetReconciler — CAPI Cluster deletion sequence before runner Job
- [ ] RunnerConfig generation from TalosCluster spec (operational Job CRDs only; not CAPI lifecycle)
- [ ] All operational CRD reconcilers (one per CRD, thirteen total via OperationalJobReconciler base)
- [ ] TalosClusterReset human gate
- [ ] Tenant namespace lifecycle management
- [ ] PlatformTenant reconciler
- [ ] ClusterAssignment reconciler with all gate conditions
- [ ] QueueProfile reconciler
- [ ] LicenseKey reconciler
- [ ] TalosUpgrade reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (talos-upgrade) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.
- [ ] TalosKubeUpgrade reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (kube-upgrade) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.
- [ ] TalosStackUpgrade reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (stack-upgrade) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.
- [ ] TalosNodeScaleUp reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (node-scale-up) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.
- [ ] TalosNodeDecommission reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (node-decommission) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.
- [ ] TalosReboot reconciler — CAPI-delegated for capi.enabled=true clusters. Retained as direct runner Job (node-reboot) for capi.enabled=false. Reconciler scope governed by OperationalJobReconciler routing rule.

### ont-infra
- [ ] PackBuild reconciler
- [ ] RunnerConfig generation from PackBuild spec
- [ ] ClusterPack reconciler
- [ ] PackExecution reconciler with execution gatekeeper
- [ ] PackInstance reconciler with drift integration

## Phase 2 — Platform Engineer
- [ ] Dockerfiles for all four components
- [ ] GitHub Actions CI workflows
- [ ] OCI push pipeline configuration

## Phase 3 — Integration and e2e Tests
- [ ] ont-security full integration test suite
- [ ] ont-runner capability integration tests
- [ ] ont-platform e2e bootstrap gate on ccs-test
- [ ] ont-infra pack compile and deploy e2e gate

## Phase 4 — Release
- [ ] Release Engineer session pending Phase 3 green gate
