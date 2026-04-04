# Seam Platform — Fast Bootstrap Context
> Read this file first. PROGRESS.md is the detailed audit record — consult on demand.

---

## 1. Platform State

| Component    | Last Commit | Status                        | Next Pending Work                                           |
|--------------|-------------|-------------------------------|-------------------------------------------------------------|
| conductor    | session/15 (uncommitted) | WS1: TalosClientAdapter/S3StorageClientAdapter/OCIRegistryClientAdapter concrete impls wired into runExecute(); WS2: real Ed25519 INV-026 signing key verification in ReceiptReconciler (NewReceiptReconcilerWithKey, SIGNING_PUBLIC_KEY_PATH env var, DegradedSecurityState on failure); WS3: SealedCausalChainWebhook and WebhookServer wired into agent.go (WEBHOOK_TLS_CERT_PATH/KEY_PATH/ADDR env vars); 71 unit tests green across 6 suites | Commit these changes; future: PackInstance/PermissionSnapshot signing loops; PermissionService gRPC (target cluster local authorization) |
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
**Component:** Guardian or Conductor

**Commit conductor Session 15 changes** then schedule next work:

**Conductor — PackInstance/PermissionSnapshot signing loops** (management cluster only; signs CRs with platform signing key; Conductor Engineer session)

**Conductor — PermissionService gRPC** (target cluster local authorization server; session in guardian-schema.md §8; Conductor Engineer session)

**Guardian — SealedCausalChain spec.lineage field embedding** (add spec.lineage to all 5 root-declaration CRD specs; Guardian Controller Engineer session)

**LineageController** — deferred until Platform and Wrapper have meaningful object-producing implementations

**Pre-conditions (Conductor commit):**
- conductor Session 15 changes uncommitted on branch `session/1-governor-init`
- All unit tests green: `go test ./... 2>&1` — 6 suites pass, 71 tests
- New files: internal/capability/adapters.go, internal/webhook/sealed_causal_chain.go
- Modified: internal/agent/receipt_reconciler.go, internal/kernel/agent.go, cmd/conductor/main.go, go.mod, go.sum
- New test files: test/unit/capability/adapters_test.go, test/unit/agent/signing_test.go, test/unit/webhook/sealed_causal_chain_test.go

**Pre-conditions (Guardian work):**
- guardian at 740be82 on branch `session/1-governor-init`
- LineageSynced initialization in all 5 reconcilers pending commit (Schema Engineer session — approved, not committed)
- KUBEBUILDER_ASSETS must be set before envtest runs

---
*Maintained by the Governor role. Refresh after every Governor session.*
