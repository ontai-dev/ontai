# ONT Platform: Codebase Reference

## System-Level Overview

ONT (Operator Native Thinking) is a governance-first Kubernetes management platform built on Talos Linux. The platform governs Talos-based Kubernetes clusters through five production operators (guardian, platform, wrapper, seam-core, conductor), one compiler binary, and two schema-only repositories (domain-core, app-core). All cross-operator CRD type definitions are owned by seam-core under `infrastructure.ontai.dev/v1alpha1`. All RBAC on every cluster is owned by guardian. All cluster lifecycle is owned by platform. All pack delivery is owned by wrapper. All execution intelligence is owned by conductor.

The platform runs in two environments:
- **Management cluster** (`ccs-mgmt`): Runs all five operators, the conductor management agent, and receives the full guardian EPG computation.
- **Target clusters** (e.g., `ccs-dev`): Run the conductor tenant agent, a guardian subset (no EPG), and receive pack deployments via the wrapper pipeline.

Lab topology: bridge `talos-br0` at `10.20.0.1/24`, management cluster VIP `10.20.0.10`, tenant cluster VIP `10.20.0.20`, local OCI registry `10.20.0.1:5000`, local Helm server `10.20.0.1:8888`.

---

## Repo Responsibility Map

| Repo | API Group | Role | Owns |
|---|---|---|---|
| `seam-core` | `infrastructure.ontai.dev/v1alpha1` | Schema authority + lineage/DSNS controllers | 12 cross-operator CRD types; InfrastructureLineageIndex; DSNS zone file; shared conditions and lineage libraries |
| `guardian` | `security.ontai.dev/v1alpha1` | RBAC governance plane | All RBAC resources on every cluster; EPG computation; PermissionSnapshot delivery and signing; CNPG audit trail |
| `platform` | `platform.ontai.dev/v1alpha1` + CAPI provider | Cluster lifecycle authority | TalosCluster create/import; machineconfig delivery (port 50000); 13 day-2 operational CRDs; seam-tenant-{cluster} namespace creation |
| `wrapper` | `infrastructure.ontai.dev/v1alpha1` (consumer) | Pack delivery engine | ClusterPack to PackExecution to pack-deploy Job to PackInstance lifecycle; 6-gate gatekeeper; workload cleanup |
| `conductor` | N/A (no CRDs defined) | Execution + compilation intelligence | 3 images: compiler (offline), execute (Kueue Jobs), agent (distroless, every cluster); drift detection; signing (management agent); 17 named capabilities |
| `domain-core` | `core.ontai.dev/v1alpha1` | Layer 0 abstract schema | DomainLineageIndex abstract type; 7 business primitive types; `pkg/lineage` shared helpers |
| `app-core` | (schema only, no CRDs yet) | Application governance layer specification | Schema for AppBoundary, AppIdentity, AppPolicy, AppTopology, AppEventSchema, AppWorkflow, AppResourceProfile, AppAuditPolicy, AppProfile |

---

## Cross-Repo Dependency Graph

```
domain-core (no external deps)
    ^
seam-core (imports domain-core/pkg/lineage for lineage helpers)
    ^
    +-- guardian (imports seam-core: TalosCluster, lineage types, conditions)
    +-- platform (imports seam-core: TalosCluster, RunnerConfig, TCOR; imports conductor/pkg/runnerlib)
    +-- wrapper  (imports seam-core: ClusterPack, PackExecution, PackInstance, PackReceipt, POR)
    +-- conductor
          +-- pkg/runnerlib (imported by platform and wrapper; contains RunnerConfig generation logic)
          +-- binary (imports seam-core for all CR types; reads guardian CRDs via unstructured to avoid circular import)
```

Import direction notes:
- `domain-core` has no ONT imports; it is the root dependency.
- All operators import `seam-core` for type definitions (Decision G).
- Operators read each other's CRDs via unstructured client to avoid circular imports.
- `conductor/pkg/runnerlib` is imported by `platform` and `wrapper`; it does not import them.
- `app-core` has no Go code; schema-only.

---

## Namespace Model

| Namespace | Contents | Creator |
|---|---|---|
| `seam-system` | All Seam operator managers, leader election leases, guardian CNPG, management-maximum PermissionSet + management-policy RBACPolicy | Enable bundle / compiler |
| `ont-system` | Conductor agent Deployment, RunnerConfig CRs, local PackReceipt mirror, PermissionSnapshot mirror (labeled `ontai.dev/snapshot-type=mirrored`), DSNS zone ConfigMap | Platform (agent Deployment), seam-core (DSNS) |
| `seam-tenant-{cluster}` | ClusterPack, PackExecution, PackInstance, PackOperationResult, DriftSignal, cluster-maximum PermissionSet, cluster-policy RBACPolicy, conductor-tenant RBACProfile, component RBACProfiles, kubeconfig Secrets, LocalQueue | Platform (namespace creation, CP-INV-004); guardian (cluster-policy, CP-INV-008 items); wrapper (pack CRs) |

---

## Key Operational Sequences

### Cluster registration (import mode)
1. Human applies `InfrastructureTalosCluster` (mode=import) to management cluster.
2. Platform creates `seam-tenant-{cluster}` namespace + RunnerConfig + Guardian allowedClusters entry + LocalQueue + executor resources + wrapper-runner resources (`ensureTenantOnboarding()` L1254 in `taloscluster_helpers.go`).
3. Platform calls `EnsureRemoteConductorBootstrap()` to deploy Conductor agent + RBAC to `ont-system` on target cluster.
4. Platform calls `EnsureRemoteTalosClusterCopy()` to copy InfrastructureTalosCluster CR to `ont-system` on target cluster.
5. Conductor agent leader elected; `CapabilityPublisher` writes 17 capabilities to RunnerConfig status.
6. Guardian `ClusterRBACPolicyReconciler.reconcileCreate()` creates cluster-maximum PermissionSet + cluster-policy + conductor-tenant RBACProfile in `seam-tenant-{cluster}`.
7. `ConductorReady=True` on TalosCluster; cluster is governed.

### Pack delivery end-to-end
1. Compiler generates ClusterPack CR YAML + pushes OCI artifact layers (RBAC, cluster-scoped, workload) to registry.
2. GitOps applies ClusterPack to `seam-tenant-{cluster}`.
3. Conductor management agent signs pack (Ed25519 private key, INV-026).
4. Wrapper `ClusterPackReconciler` detects `status.Signed=true`, creates PackExecution.
5. `PackExecutionReconciler` runs 6 gates (0: ConductorReady, 1: Signature, 2: Revocation, 3: PermissionSnapshot, 4: RBACProfile, 5: WrapperRunnerRBAC). All must pass.
6. pack-deploy Kueue Job submitted (`conductor-execute:dev` image). Conductor execute-mode `executeSplitPath()` applies RBAC via guardian HTTP intake, applies cluster-scoped + workload layers to tenant cluster, writes PackReceipt, writes PackOperationResult.
7. Wrapper `PackExecutionReconciler` reads POR via `findLatestPOR()`, creates PackInstance on management cluster.
8. Tenant conductor `PackInstancePullLoop` pulls signed PackInstance artifact, verifies Ed25519, writes PackReceipt with chart metadata via `buildReceiptSpecPayload()`.
9. Tenant conductor `PackReceiptDriftLoop.checkDrift()` verifies each resource in `spec.deployedResources` exists on local cluster.

### RBAC governance cycle
1. Guardian `ClusterRBACPolicyReconciler.reconcileCreate()` creates cluster-maximum PermissionSet + cluster-policy RBACPolicy in `seam-tenant-{cluster}`.
2. Compiler `component` subcommand generates component RBACProfile CRs.
3. `RBACProfileReconciler` validates profile ceiling against management-maximum; sets `status.provisioned=true`.
4. `EPGReconciler` computes EPG from all provisioned RBACProfiles + PermissionSets; writes PermissionSnapshot CRs.
5. Conductor management agent signs PermissionSnapshot (INV-026).
6. Tenant conductor `SnapshotPullLoop` pulls PermissionSnapshot from management, verifies signature, caches in `SnapshotStore`.
7. Guardian `TenantSnapshotRunnable` on tenant mirrors PermissionSnapshot to `ont-system` with label `ontai.dev/snapshot-type=mirrored`.
8. PackExecution Gate 3 (`isPermissionSnapshotCurrent()`) reads mirrored snapshot; allows pack-deploy Job only when snapshot is current.

---

## Three-Image Conductor Model (Decision 12)

| Image | Dockerfile | Base | Mode | Constraint |
|-------|-----------|------|------|------------|
| `compiler:dev` | `Dockerfile.compiler` | debian-slim | compile | Never deployed to cluster |
| `conductor-execute:dev` | `Dockerfile.execute` | debian-slim | execute | Kueue Job pods on management cluster only |
| `conductor:dev` | `Dockerfile.agent` | distroless/base:nonroot | agent | Deployed to `ont-system` on every cluster |

**Critical**: Pushing `conductor:dev` does NOT update pack-deploy Job pods -- those use `conductor-execute:dev`. Always build both after changes to shared code.

---

## Architecture Invariants (Cross-Cutting)

| # | Rule | Where Enforced |
|---|---|---|
| INV-001 | No shell scripts; Go only | Code review |
| INV-002 | Operators are thin reconcilers; no execution logic | Architecture pattern |
| INV-003 | Guardian deploys first; all operators wait for `RBACProfile.provisioned=true` | Enable bundle order |
| INV-004 | Guardian owns all RBAC on every cluster | Admission webhook (decision.go) |
| INV-006 | No Jobs on delete path | `handleTalosClusterDeletion()`, `handleClusterPackDeletion()` |
| INV-007 | Destructive operations require affirmative CR with human approval gate | `clusterreset_reconciler.go` annotation check |
| INV-010 | seam-core is the single source of RunnerConfig and cross-operator CRD type definitions | Decision G |
| INV-013 | Talos goclient permitted only in SeamInfrastructureClusterReconciler and SeamInfrastructureMachineReconciler | `seaminfrastructuremachine_reconciler.go`, `seaminfrastructurecluster_reconciler.go` |
| INV-022 | Long-lived Deployment images are distroless; execute-mode images are debian-slim | `Dockerfile.agent`, `Dockerfile.execute` |
| INV-023 | Always `:dev` tag in lab; custom per-build tags never committed to any artifact | Enable bundle YAML files |
| INV-026 | PackInstance and PermissionSnapshot signing are management-cluster Conductor only | `signing_loop.go`, `--signing-private-key` flag rejected for tenant in compiler enable |

---

## Open Items Summary

| Item | Repo | Status |
|------|------|--------|
| T-04a: TalosCluster CEL validation for mode=import | seam-core | Open -- no `x-kubernetes-validations` in CRD YAML |
| T-05: PackBuildInput Category field in conductor compiler | conductor | Open -- seam-core schema has Category enum; `PackBuildInput` struct has no field |
| T-17: Scoped RBACPolicy pull loop for conductor role=tenant | conductor | Open -- PermissionSnapshot loop present; RBACPolicy pull absent |
| T-23: Platform DriftSignal handling | platform | Open -- design session required |
| T-24: TalosCluster deletion cascade per Decision H order | platform + conductor | Open -- `handleTalosClusterDeletion()` only covers RunnerConfig + Secrets + namespace |
| T-25a: RBACProfile admission webhook gate | guardian | Open -- `RBACProfile` absent from `InterceptedKinds` |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor | Open -- no pull loop for conductor-tenant RBACProfile from management to ont-system |
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | platform | Open -- `wrapper-runner-{cluster}` ClusterRoleBinding not deleted on TalosCluster deletion |
| CLUSTERPACK-BL-VERSION-CLEANUP | conductor | Open -- version-upgrade orphan diff absent from `packinstance_pull_loop.go`; schema done |

---

## Repo-Level CODEBASE.md Index

- [conductor/CODEBASE.md](conductor/CODEBASE.md) -- Compiler binary, 17 named capabilities, execute/agent mode, pack-deploy split path, drift detection loops, signing loop
- [guardian/CODEBASE.md](guardian/CODEBASE.md) -- RBAC governance plane, EPG computation, PermissionSnapshot delivery, admission webhook (InterceptedKinds), CNPG audit trail, tenant snapshot runnable
- [platform/CODEBASE.md](platform/CODEBASE.md) -- Cluster lifecycle (CAPI + direct bootstrap), machineconfig delivery (port 50000), 13 operational CRDs, handleTalosClusterDeletion gaps (T-24)
- [seam-core/CODEBASE.md](seam-core/CODEBASE.md) -- 12 CRD type definitions, LineageReconciler, DSNSReconciler, OutcomeReconciler, shared conditions/lineage libraries, T-04a (CEL validation absent)
- [wrapper/CODEBASE.md](wrapper/CODEBASE.md) -- 6-gate PackExecution gatekeeper, ClusterPack deletion finalizer, findLatestPOR, CLUSTERPACK-BL-VERSION-CLEANUP (schema done, logic absent)
- [domain-core/CODEBASE.md](domain-core/CODEBASE.md) -- Layer 0 abstract schema, DomainLineageIndex, 7 business primitives, no controller
- [app-core/CODEBASE.md](app-core/CODEBASE.md) -- Application governance layer schema (specification-only, no implementation)

---

## Where to Start for Common Tasks

**Adding a new named capability to Conductor**: Read `conductor/docs/conductor-schema.md`, then `conductor/internal/capability/` for Handler interface. Register in `cmd/conductor/main.go`. Write unit tests in `test/unit/capability/`. Add e2e stub referencing backlog item ID.

**Deploying a new pack**: Write PackBuildInput YAML with `rawSource` or `helmSource`. Run `compiler packbuild`. Commit emitted ClusterPack CR to `lab/configs/{cluster}/compiled/clusterpack/`. Apply to cluster. Monitor `kubectl get clusterpack,packexecution,packinstance -A`.

**Adding a new cross-operator CRD**: Goes in seam-core first (Decision G). Schema to ontai-schema first (Decision 11). CRD YAML in `config/crd/`. Run `make generate-crd`. Operator implementation PRs only after schema PR merges.

**Debugging pack-deploy failure**: Check PackExecution conditions for which gate is blocked. Check the `pack-deploy-{pe.Name}` Kueue Job logs in `seam-tenant-{cluster}`. Check `PackOperationResult` CR for failure category and step results.

**Understanding why a cluster is not Ready**: Check `TalosCluster.status.conditions`. Common blockers: `ConductorReady=False` (agent not deployed or leader not elected), `CiliumPending=True` (Cilium PackExecution not complete -- this is NOT degraded, CP-INV-013), `ControlPlaneUnreachable=True` (machineconfig delivery failed after 3 attempts, `machineApplyAttemptsHaltThreshold=3`).
