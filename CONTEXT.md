# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | 05b63e6     | Binary entry points, capability engine, execute/agent mode stubs complete | ConfigMap write after execute dispatch (stub TODO), leader election, control loops |
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
| Controller Engineer     | platform-schema.md + platform/platform-design.md (Platform work)                        |
| Controller Engineer     | wrapper-schema.md + wrapper/wrapper-design.md (Wrapper work)                              |
| Conductor Engineer      | conductor-schema.md + conductor/conductor-design.md + all operator *-schema.md             |
| Platform Engineer       | Target component *-schema.md + Dockerfile context for that component                        |
| Test Engineer           | Target *-schema.md + target component *-design.md                                           |
| Lab Operator            | ont-lab/ runbooks + CLAUDE.md §9                                                             |
| Release Engineer        | GIT_TRACKING.md, BACKLOG.md                                                                  |
| Incident Analyst        | PROGRESS.md + target component *-schema.md                                                   |

---

## 4. Next Session

**Role:** Governor scheduling required
**Component:** Guardian or Conductor

**Guardian — SealedCausalChain immutability webhook** (admission webhook, Guardian Controller Engineer session)

**Conductor — execute-mode ConfigMap write** (OperationResultSpec → ConfigMap, the only output channel between operator and Conductor Job; next Conductor Engineer session)

**LineageController — deferred** until Platform and Wrapper have meaningful object-producing implementations

**Pre-conditions (Guardian work):**
- guardian at 740be82 on branch `session/1-governor-init`
- KUBEBUILDER_ASSETS is set in the test environment before running integration tests
- All unit and integration tests currently green

**Pre-conditions (Conductor work):**
- conductor at 05b63e6 on branch `session/1-governor-init`
- All unit tests green: `go test ./test/unit/...` from conductor root
- WS1–WS3 complete; next work is kernel/execute.go Phase 4 (ConfigMap write) and agent mode control loops

---
*Maintained by the Governor role. Refresh after every Governor session.*
