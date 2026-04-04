# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | 0ccbb2a     | WS1: SigningLoop signs PackInstance+PermissionSnapshot CRs with Ed25519 (SIGNING_PRIVATE_KEY_PATH gate, management cluster only, INV-026); WS2: local PermissionService gRPC (SnapshotStore + LocalService + hand-written service descriptor, PERMISSION_SERVICE_ADDR, all clusters); 7 suites, all green | PermissionSnapshot pull loop (target cluster pull from management); Guardian SealedCausalChain spec.lineage embedding |
| guardian     | 740be82     | IdentityBinding trust methods, PermissionSet reconciler, PermissionService gRPC complete | SealedCausalChain immutability webhook, LineageController (deferred) |
| platform     | 7237416     | Skeleton only                 | TalosCluster reconciler (bootstrap + CAPI paths)            |
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

**Role:** Governor scheduling required
**Component:** Guardian (immediate) or Conductor (pull loop)

**Guardian — SealedCausalChain spec.lineage field embedding** (add spec.lineage to all 5 root-declaration CRD specs; Schema Engineer session; approved by Governor Directive §14 Decision 6)

**Conductor — PermissionSnapshot pull loop** (target cluster pulls PermissionSnapshot from management cluster, verifies signature, updates SnapshotStore; required for local PermissionService to serve live data)

**LineageController** — deferred until Platform and Wrapper have meaningful object-producing implementations

**Pre-conditions (Guardian work):**
- guardian at 740be82 on branch `session/1-governor-init`
- Add spec.lineage to: TalosCluster, PackExecution, RBACProfile, PermissionSet, IdentityBinding CRD specs
- LineageSynced initialization in all 5 reconcilers pending commit (Schema Engineer session — approved, not committed)
- KUBEBUILDER_ASSETS must be set before envtest runs

**Pre-conditions (Conductor pull loop):**
- conductor at 0ccbb2a on branch `session/1-governor-init`
- All 7 suites green: `go test ./...`
- SnapshotStore.Update is the population API; wired into local PermissionService

---
*Maintained by the Governor role. Refresh after every Governor session.*
