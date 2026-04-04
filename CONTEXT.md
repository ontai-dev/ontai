# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | bcbb224     | Shared library complete       | Binary entry points, capability engine, execute/agent modes |
| guardian     | 740be82     | Session 11 complete — WS1+WS2+WS3 all green | Admission webhook enforcement, CNPG persistence, PermissionSnapshot signing |
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
| Controller Engineer     | guardian-schema.md + guardian/guardian-design.md (Guardian work)                        |
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

**Guardian — remaining major work:**
- Admission webhook enforcement (CS-INV-001): webhook currently validates annotation ownership;
  ExecutionGatekeeper (§11) requires PackExecution admission intercept with four-condition check
- CNPG persistence: Phase 2 boot (database-backed EPG persistence), CS-INV-002/003
- PermissionSnapshot signing wiring: conductor agent-mode signing handoff (INV-026)
- RBACProfile provisioned=true gate: currently written but EPG only uses provisioned profiles;
  the gate itself is functional

**Conductor — remaining major work:**
- Binary entry points (compile/execute/agent modes)
- Capability engine (capability manifest declaration on startup)
- Execute-mode capability implementations

**Pre-conditions (Guardian work):**
- guardian at 740be82 on branch `session/1-governor-init`
- KUBEBUILDER_ASSETS is set in the test environment before running integration tests
- All unit and integration tests currently green

**Session 11 deliverables (all committed at 740be82):**
- WS1: IdentityBinding trust methods — IdentityProviderRef resolution, TrustAnchorResolved
  condition, 8 unit tests + 5 integration tests
- WS2: PermissionSet reconciler — ProfileReferenceCount tracking, PermissionSetValid
  condition, 4 integration tests
- WS3: PermissionService gRPC — InMemoryEPGStore, Service (CheckPermission/ListPermissions/
  WhoCanDo/ExplainDecision), gRPC server with manual ServiceDesc + JSON codec,
  EPGReconciler Store update, 16 unit tests

---
*Maintained by the Governor role. Refresh after every Governor session.*
