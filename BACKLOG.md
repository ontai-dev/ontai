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
- [x] PermissionSnapshot generation (Session 5); delivery to target cluster agents deferred to Session 6
- [ ] PermissionSnapshot push delivery to target cluster agents (Session 6)
- [ ] PermissionSnapshotReceipt watch and LastAckedVersion propagation (Session 6)
- [ ] reconcileDrift wiring in EPGReconciler — TODO(session-6) marker present
- [ ] Admission webhook server — TODO in main.go (Session 5 or later)
- [ ] PermissionService gRPC server (4 operations)
- [ ] CNPG two-phase boot sequence (CS-INV-003)
- [x] IdentityBinding reconciler — stub only (Session 4); full EPG trigger wiring deferred to Session 5
- [x] PermissionSet types and validation (Session 4)
- [ ] PermissionSet reconciler (owns ProfileReferenceCount maintenance)
- [ ] Third-party RBAC intake process
- [ ] controller-gen wiring (replaces handwritten CRD YAML and zz_generated.deepcopy.go)

### ont-platform
- [ ] TalosCluster reconciler (bootstrap and import modes)
- [ ] RunnerConfig generation from TalosCluster spec
- [ ] All operational CRD reconcilers (one per CRD)
- [ ] TalosClusterReset human gate
- [ ] Tenant namespace lifecycle management
- [ ] PlatformTenant reconciler
- [ ] ClusterAssignment reconciler with all gate conditions
- [ ] QueueProfile reconciler
- [ ] LicenseKey reconciler

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
