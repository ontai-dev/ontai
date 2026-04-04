# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 0. Anti-Patterns (FORBIDDEN)
- Adding Co-Authored-By trailers to commits

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | 5e5bebb     | WS1: SigningLoop signs PackInstance+PermissionSnapshot CRs with Ed25519 (SIGNING_PRIVATE_KEY_PATH gate, management cluster only, INV-026); WS2: local PermissionService gRPC (SnapshotStore + LocalService + hand-written service descriptor, PERMISSION_SERVICE_ADDR, all clusters); WS3: SnapshotPullLoop — target cluster pulls PermissionSnapshot from management, verifies Ed25519 (SIGNING_PUBLIC_KEY_PATH + MGMT_KUBECONFIG_PATH gates), calls SnapshotStore.Update; DegradedSecurityState on failure; bootstrap window mode (INV-020); 7 suites, all green | Guardian SealedCausalChain spec.lineage embedding |
| guardian     | d3b5e74     | WS1: SealedCausalChain spec.lineage added to RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet; CRDs regenerated; seam-core dependency wired; WS2: LineageSynced=False/LineageControllerAbsent initialization in all 5 reconcilers; lineage_conditions.go added; WS3 (session/24): lineage_immutability.go + lineage_handler.go + RegisterLineage — rejects spec.lineage UPDATE on all 5 root-declaration kinds; 16 new unit tests green | SealedCausalChain immutability webhook — CLOSED session/24 |
| platform     | 5dbe1aa     | TalosCluster + SeamInfrastructureCluster/Machine CRD types, all three reconcilers (TalosCluster, SIC, SIM), SIC/SIM CRDs with lineage + controller-gen clean, SIM implements 6-step machineconfig delivery via TalosMachineConfigApplier (only file with talos goclient, CP-INV-001 clean), unit tests green, go build clean | Wrapper ClusterPack/PackExecution/PackInstance reconcilers |
| wrapper      | 3438aec     | WS1: ClusterPack/PackExecution/PackInstance CRDs + deepcopy + 3 CRD YAMLs; WS2: ClusterPackReconciler (immutability enforcement, signature transition, SignaturePending requeue), PackExecutionReconciler (4-gate check, Kueue Job submission, OperationResult read); WS3: PackInstanceReconciler (PackReceipt drift/security, DependencyBlock); spec.lineage (SealedCausalChain) embedded in all 3 root-declaration specs, CRD YAMLs regenerated; 17 unit tests green | Governor scheduling for remaining deferred items |
| seam-core    | 54d4409     | LineageController complete (be0aaa1); session/24: WS2+WS3 — ILI immutability webhook (spec.rootBinding UPDATE rejected), controller-authorship gate (CREATE/UPDATE allowed only from lineage-controller SA), both wired into cmd/seam-core/main.go; 29 new unit tests green | Governor scheduling for remaining deferred items |

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

**Role:** Governor
**Purpose:** Review remaining deferred items, schedule next session: CapabilityRBACProvision (Conductor Engineer, conductor repo).

**LineageController — CLOSED.** seam-core be0aaa1 delivers:
- Full InfrastructureLineageIndex spec (rootBinding, descendantRegistry, policyBindingStatus)
- controller-gen wiring (Makefile with generate-deepcopy + generate-crd targets)
- cmd/seam-core/main.go manager entry point (leader election, 9 GVK registrations)
- LineageReconciler watching all 9 root-declaration GVKs across 3 operators
- governance.infrastructure.ontai.dev annotation sub-prefix enforcement
- LineageSynced condition ownership transfer (False/LineageControllerAbsent → True/LineageIndexCreated)
- 9 unit tests, all green

**Remaining deferred items to schedule:**
- ~~SealedCausalChain immutability admission webhook (guardian + seam-core)~~ CLOSED session/24 — guardian d3b5e74 (5 kinds), seam-core 54d4409 (ILI rootBinding)
- ~~LineageIndex controller-authorship admission webhook (seam-core)~~ CLOSED session/24 — seam-core 54d4409 (lineage-controller SA gate)
- Guardian CapabilityRBACProvision executor mode (conductor) — NEXT SESSION
- ~~Wrapper SealedCausalChain spec.lineage embedding~~ CLOSED — delivered in session 21 (3438aec); confirmed session 23

---
*Maintained by the Governor role. Refresh after every Governor session.*
