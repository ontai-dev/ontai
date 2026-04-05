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
| conductor    | 2efc758     | WS1: SigningLoop signs PackInstance+PermissionSnapshot CRs with Ed25519 (SIGNING_PRIVATE_KEY_PATH gate, management cluster only, INV-026); WS2: local PermissionService gRPC (SnapshotStore + LocalService + hand-written service descriptor, PERMISSION_SERVICE_ADDR, all clusters); WS3: SnapshotPullLoop — target cluster pulls PermissionSnapshot from management, verifies Ed25519 (SIGNING_PUBLIC_KEY_PATH + MGMT_KUBECONFIG_PATH gates), calls SnapshotStore.Update; DegradedSecurityState on failure; bootstrap window mode (INV-020); session/25: CapabilityRBACProvision — Ed25519 signature verification (INV-026), bootstrap window bypass (INV-020), SigningPublicKey field added to ExecuteClients; session/governor (WS1): Compiler subcommand model corrected — CR compiler (bootstrap/launch/enable/packbuild/domain), SOPS/Helm/Kustomize are Conductor Execute Mode concerns not Compiler concerns (F-P2 closed); 7 suites green | — |
| guardian     | 68ebe07     | WS1: SealedCausalChain spec.lineage added to RBACPolicy, RBACProfile, IdentityBinding, IdentityProvider, PermissionSet; CRDs regenerated; seam-core dependency wired; WS2: LineageSynced=False/LineageControllerAbsent initialization in all 5 reconcilers; lineage_conditions.go added; WS3 (session/24): lineage_immutability.go + lineage_handler.go + RegisterLineage — rejects spec.lineage UPDATE on all 5 root-declaration kinds; 16 new unit tests green | SealedCausalChain immutability webhook — CLOSED session/24 |
| platform     | 76accc5     | TalosCluster + SeamInfrastructureCluster/Machine CRD types, all three reconcilers (TalosCluster, SIC, SIM), SIC/SIM CRDs with lineage + controller-gen clean, SIM implements 6-step machineconfig delivery via TalosMachineConfigApplier (only file with talos goclient, CP-INV-001 clean), unit tests green, go build clean | Wrapper ClusterPack/PackExecution/PackInstance reconcilers |
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
| F-P1  | Day-2 CRD types and reconcilers absent in platform — EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile, UpgradePolicy, NodeOperation, ClusterMaintenance types and reconcilers are not implemented. Conductor capability handlers reference these CRDs but no Go types or CRD YAML exist in the platform repo. Requires a Platform Controller Engineer session. | No |
| F-P2  | ~~Compiler subcommand model corrected~~ CLOSED session/governor (WS2) — conductor 2efc758. Compiler is a CR compiler: reads human-authored spec files and emits Kubernetes CR YAML only. Correct subcommands: `bootstrap`, `launch`, `enable` (all produce TalosCluster CR YAML), `packbuild` (produces ClusterPack CR YAML), `domain` (reserved). SOPS, Helm, and Kustomize are execution-mode concerns owned by Conductor Execute Mode — not Compiler concerns. Stubs return honest not-implemented errors; actual blockers are CR type integration from platform and wrapper libraries. | Closed |
| F-P3  | Non-CAPI cluster lifecycle scope unverified — spec.capi.enabled=false path was framed around management cluster provisioning in Session 19. Whether it covers the full lifecycle of a natively bootstrapped non-CAPI target cluster including node join, worker expansion, and decommission is unconfirmed. Requires verification against platform-design.md and a Platform Controller Engineer session if gaps are found. | No |

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
**Purpose:** Schedule F-P1 (platform day-2 CRDs) and F-P3 (non-CAPI lifecycle scope verification). F-P2 closed — Compiler is a CR compiler with correct subcommands (bootstrap/launch/enable/packbuild/domain); execution-mode clients (SOPS, Helm, Kustomize) belong to Conductor Execute Mode, not the Compiler.

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
- ~~Guardian CapabilityRBACProvision executor mode (conductor)~~ CLOSED session/25 — conductor 2e2afa9
- ~~Wrapper SealedCausalChain spec.lineage embedding~~ CLOSED — delivered in session 21 (3438aec); confirmed session 23

---
*Maintained by the Governor role. Refresh after every Governor session.*
*Section 4 (Namespace Model) locked 2026-04-05 by Governor directive.*
