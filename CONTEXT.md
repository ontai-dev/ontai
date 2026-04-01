# ONT Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| ont-runner   | bcbb224     | Shared library complete       | Binary entry points, capability engine, agent/compile modes |
| ont-security | 8324c0b     | Admission webhook operational | Bootstrap RBAC window (TODO session-8, INV-020, CS-INV-004) |
| ont-platform | 7237416     | Skeleton only                 | TalosCluster reconciler (bootstrap + CAPI paths)            |
| ont-infra    | 86807d4     | Skeleton only                 | ClusterPack, PackExecution, PackInstance reconcilers        |

---

## 2. Open Findings

| ID    | Description                                                                    | Blocking?                              |
|-------|--------------------------------------------------------------------------------|----------------------------------------|
| F-S1  | Repo subdirectories not yet created in component repos                         | No                                     |
| F-S3  | CRD YAML and DeepCopy are handwritten; controller-gen not wired (growing risk) | Yes — before any new CRD type additions |
| F-S3B | KUBEBUILDER_ASSETS must be set manually for envtest runs                       | No (infra note)                        |
| F-6D  | CapabilityRBACProvision executor-mode confirmed; implementation pending        | No — requires Runner Engineer session  |

---

## 3. Role Reading Map

| Role                | Required Documents (beyond CONTEXT.md)                                                   |
|---------------------|------------------------------------------------------------------------------------------|
| Governor            | PROGRESS.md, GIT_TRACKING.md, BACKLOG.md                                                 |
| Domain Architect    | *-schema.md for target domain                                                            |
| Schema Engineer     | Target *-schema.md + target component *-design.md + existing CRD YAML in that repo      |
| Controller Engineer | ont-security-schema.md + ont-security/ont-security-design.md (ont-security work)        |
| Controller Engineer | ont-platform-schema.md + ont-platform/ont-platform-design.md (ont-platform work)        |
| Controller Engineer | ont-infra-schema.md + ont-infra/ont-infra-design.md (ont-infra work)                    |
| Runner Engineer     | ont-runner-schema.md + ont-runner/ont-runner-design.md + all operator *-schema.md       |
| Platform Engineer   | Target component *-schema.md + Dockerfile context for that component                    |
| Test Engineer       | Target *-schema.md + target component *-design.md                                       |
| Lab Operator        | ont-lab/ runbooks + CLAUDE.md §10                                                        |
| Release Engineer    | GIT_TRACKING.md, BACKLOG.md                                                              |
| Incident Analyst    | PROGRESS.md + target component *-schema.md                                               |

---

## 4. Next Session

**Role:** Controller Engineer
**Objective:** Bootstrap RBAC window — close TODO(session-8) in `internal/webhook/decision.go`,
enforce INV-020 and CS-INV-004. Webhook must admit bootstrap operations during the window and
harden permanently after ont-security's admission webhook becomes operational.
**Pre-conditions:**
- ont-security at 8324c0b on branch `session/1-governor-init`
- `internal/webhook/decision.go` contains `TODO(session-8)` bootstrap window stub
- KUBEBUILDER_ASSETS is set in the test environment before running integration tests

---
*Maintained by the Governor role. Refresh after every Governor session.*
