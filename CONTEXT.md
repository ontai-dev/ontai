# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | bcbb224     | Shared library complete       | Binary entry points, capability engine, execute/agent modes |
| guardian     | 52e1bb6     | Bootstrap RBAC window closed  | PermissionSet reconciler, PermissionService gRPC, controller-gen |
| platform     | 7237416     | Skeleton only                 | TalosCluster reconciler (bootstrap + CAPI paths)            |
| wrapper      | 86807d4     | Skeleton only                 | ClusterPack, PackExecution, PackInstance reconcilers        |
| seam-core    | c6d4626     | Initialized — skeleton only   | Schema controller implementation                            |

---

## 2. Open Findings

| ID    | Description                                                                    | Blocking?                              |
|-------|--------------------------------------------------------------------------------|----------------------------------------|
| F-S1  | Repo subdirectories not yet created in component repos                         | No                                     |
| F-S3  | CRD YAML and DeepCopy are handwritten; controller-gen not wired (growing risk) | Yes — before any new CRD type additions |
| F-S3B | KUBEBUILDER_ASSETS must be set manually for envtest runs                       | No (infra note)                        |
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
**Options (Governor decides):**
- Guardian: PermissionSet reconciler (ProfileReferenceCount) — no blocking prerequisite
- Guardian: PermissionService gRPC server (4 operations) — no blocking prerequisite
- Guardian: controller-gen wiring (F-S3) — REQUIRES GOVERNOR SCHEDULING, blocks new CRD type additions
- Guardian: IdentityProvider reconciler — PREREQUISITE before IdentityBinding identity trust methods
- Conductor: binary entry points, capability engine (next major work stream)
**Pre-conditions (Guardian work):**
- guardian at 52e1bb6 on branch `session/1-governor-init`
- KUBEBUILDER_ASSETS is set in the test environment before running integration tests

---
*Maintained by the Governor role. Refresh after every Governor session.*
