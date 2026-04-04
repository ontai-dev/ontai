# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | 5e5bebb     | WS1: SigningLoop signs PackInstance+PermissionSnapshot CRs with Ed25519 (SIGNING_PRIVATE_KEY_PATH gate, management cluster only, INV-026); WS2: local PermissionService gRPC (SnapshotStore + LocalService + hand-written service descriptor, PERMISSION_SERVICE_ADDR, all clusters); WS3: SnapshotPullLoop — target cluster pulls PermissionSnapshot from management, verifies Ed25519 (SIGNING_PUBLIC_KEY_PATH + MGMT_KUBECONFIG_PATH gates), calls SnapshotStore.Update; DegradedSecurityState on failure; bootstrap window mode (INV-020); 7 suites, all green | Guardian SealedCausalChain spec.lineage embedding |
| guardian     | 9a9432a     | WS1: SealedCausalChain spec.lineage added to RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet; CRDs regenerated; seam-core dependency wired; WS2: LineageSynced=False/LineageControllerAbsent initialization in all 5 reconcilers; lineage_conditions.go added | LineageController (deferred), SealedCausalChain immutability webhook (deferred) |
| platform     | 8c02a4f     | TalosCluster CRD types (bootstrap/import modes, CAPI path, LineageSynced), TalosClusterReconciler (direct bootstrap Job path + CAPI path — all 10 CAPI helpers, Cilium gate, transitionToReady), main.go with CP-INV-007 leader election, controller-gen clean, go build clean | SeamInfrastructureCluster/Machine CRD types + reconcilers (WS2 deferred) |
| wrapper      | 86807d4     | Skeleton only                 | ClusterPack, PackExecution, PackInstance reconcilers        |
| seam-core    | c6d4626     | Initialized — skeleton only   | Schema controller implementation                            |

---

## 2. Open Findings

| ID    | Description                                                                    | Blocking?                              |
|-------|--------------------------------------------------------------------------------|----------------------------------------|
| F-S1  | Repo subdirectories not yet created in component repos                         | No                                     |
| F-S3  | ~~CRD YAML and DeepCopy are handwritten; controller-gen not wired~~ CLOSED Session 9 | Closed |
| F-S3B | KUBEBUILDER_ASSETS must be set manually for envtest runs                       | No (infra note)                        |
| F-S3C | ~~PermissionRule.Verbs requires typed Verb string~~ CLOSED Session 10 — Verb type added, CRD enum restored | Closed |
| F-6D  | CapabilityRBACProvision executor-mode confirmed; implementation pending        | No — requires Conductor Engineer session |

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

## 4. Next Session

**Role:** Platform Controller Engineer
**Component:** platform

**Platform — SeamInfrastructureCluster and SeamInfrastructureMachine reconcilers** (WS2). These are the Seam CAPI Infrastructure Provider reconcilers. Only these two reconcilers may use talos goclient (INV-013, CP-INV-001). Implement:
1. SeamInfrastructureCluster and SeamInfrastructureMachine CRD types (API group: `infrastructure.cluster.x-k8s.io`) in `api/infrastructure/v1alpha1/`
2. SeamInfrastructureClusterReconciler — sets status.ready=true when all CP machines ready, writes controlPlaneEndpoint back to CAPI Cluster
3. SeamInfrastructureMachineReconciler — 6-step machineconfig delivery via talos goclient (platform-design.md §3.1)
4. Wire both reconcilers into main.go
5. Unit tests green

**LineageController** — deferred until Platform and Wrapper have meaningful object-producing implementations.

**Pre-conditions (SeamInfrastructureCluster/Machine reconcilers):**
- platform at 8c02a4f on branch `session/1-governor-init`
- TalosClusterReconciler fully implemented and committed
- Read platform-design.md §3 (Seam Infrastructure Provider) before starting
- talos goclient is ONLY permitted in these two files — any other file importing it is CP-INV-001 violation

---
*Maintained by the Governor role. Refresh after every Governor session.*
